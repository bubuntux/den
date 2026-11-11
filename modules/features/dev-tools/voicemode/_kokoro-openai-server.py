"""Serve Kokoro behind the OpenAI text-to-speech API.

Implements the subset VoiceMode calls: POST /v1/audio/speech (pcm or wav,
streamed one sentence at a time), GET /v1/models and GET /v1/audio/voices.
The model and voices are read from --model-dir; nothing is downloaded.
"""

import argparse
import io
import json
import logging
import threading
import time
import wave
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import numpy as np
from kokoro import KModel, KPipeline

LOGGER = logging.getLogger("kokoro-openai-server")

SAMPLE_RATE = 24000
REPO_ID = "hexgrad/Kokoro-82M"
# Kokoro splits only on newlines by default, which synthesises a whole
# paragraph before the first byte goes out.
SENTENCE_BREAK = r"(?<=[.!?])\s+|\n+"


class Synthesizer:
    def __init__(self, model_dir: Path, default_voice: str):
        self.voices_dir = model_dir / "voices"
        self.voices = sorted(path.stem for path in self.voices_dir.glob("*.pt"))
        if default_voice not in self.voices:
            raise ValueError(f"voice {default_voice!r} is not in {self.voices_dir}")
        self.default_voice = default_voice
        self.model = KModel(
            repo_id=REPO_ID,
            config=str(model_dir / "config.json"),
            model=str(model_dir / "kokoro-v1_0.pth"),
        ).eval()
        self.pipelines: dict[str, KPipeline] = {}
        self.lock = threading.Lock()

    def pipeline_for(self, voice: str) -> KPipeline:
        # A voice id starts with its language code: af_heart is American English.
        lang_code = voice[0]
        if lang_code not in self.pipelines:
            self.pipelines[lang_code] = KPipeline(lang_code=lang_code, repo_id=REPO_ID, model=self.model)
        return self.pipelines[lang_code]

    def sentences(self, text: str, requested_voice: str, speed: float):
        voice = requested_voice if requested_voice in self.voices else self.default_voice
        voice_file = str(self.voices_dir / f"{voice}.pt")
        with self.lock:
            pipeline = self.pipeline_for(voice)
            for result in pipeline(text, voice=voice_file, speed=speed, split_pattern=SENTENCE_BREAK):
                if result.audio is None:
                    continue
                samples = np.clip(result.audio.numpy(), -1.0, 1.0)
                yield (samples * 32767).astype(np.int16).tobytes()


def log_timing(sentences, character_count: int):
    started = time.monotonic()
    first_audio = None
    audio_bytes = 0
    for pcm in sentences:
        if first_audio is None:
            first_audio = time.monotonic() - started
        audio_bytes += len(pcm)
        yield pcm
    LOGGER.info(
        "synthesised %d characters into %.1f s of speech: first audio %.0f ms, all %.0f ms",
        character_count,
        audio_bytes / (2 * SAMPLE_RATE),
        (first_audio or 0) * 1000,
        (time.monotonic() - started) * 1000,
    )


class SpeechServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, synthesizer: Synthesizer):
        super().__init__(address, SpeechRequestHandler)
        self.synthesizer = synthesizer


class SpeechRequestHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server: SpeechServer

    def log_message(self, format, *args):
        LOGGER.info("%s %s", self.address_string(), format % args)

    def send_json(self, status: HTTPStatus, body) -> None:
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def send_error_json(self, status: HTTPStatus, message: str) -> None:
        self.send_json(status, {"error": {"message": message, "type": "invalid_request_error"}})

    def do_GET(self) -> None:
        if self.path in ("/", "/health", "/v1"):
            self.send_json(HTTPStatus.OK, {"status": "ok"})
        elif self.path == "/v1/models":
            self.send_json(
                HTTPStatus.OK,
                {"object": "list", "data": [{"id": "kokoro", "object": "model", "owned_by": "hexgrad"}]},
            )
        elif self.path == "/v1/audio/voices":
            self.send_json(HTTPStatus.OK, {"voices": self.server.synthesizer.voices})
        else:
            self.send_error_json(HTTPStatus.NOT_FOUND, f"no route for GET {self.path}")

    def do_POST(self) -> None:
        if self.path != "/v1/audio/speech":
            self.send_error_json(HTTPStatus.NOT_FOUND, f"no route for POST {self.path}")
            return

        try:
            length = int(self.headers.get("Content-Length", 0))
            request = json.loads(self.rfile.read(length) or b"{}")
            text = str(request.get("input", "")).strip()
            voice = str(request.get("voice", ""))
            response_format = request.get("response_format", "pcm")
            speed = float(request.get("speed") or 1.0)
        except (ValueError, TypeError) as error:
            self.send_error_json(HTTPStatus.BAD_REQUEST, f"malformed request: {error}")
            return

        if not text:
            self.send_error_json(HTTPStatus.BAD_REQUEST, "input is empty")
            return
        if response_format not in ("pcm", "wav"):
            self.send_error_json(
                HTTPStatus.BAD_REQUEST,
                f"response_format {response_format!r} unsupported; use pcm or wav",
            )
            return
        if not 0.25 <= speed <= 4.0:
            self.send_error_json(HTTPStatus.BAD_REQUEST, "speed must be between 0.25 and 4.0")
            return

        sentences = log_timing(self.server.synthesizer.sentences(text, voice, speed), len(text))
        if response_format == "wav":
            self.send_wav(sentences)
        else:
            self.send_pcm_stream(sentences)

    def send_wav(self, sentences) -> None:
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(SAMPLE_RATE)
            for pcm in sentences:
                wav_file.writeframes(pcm)
        payload = buffer.getvalue()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def send_pcm_stream(self, sentences) -> None:
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "audio/pcm")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        try:
            for pcm in sentences:
                self.wfile.write(f"{len(pcm):X}\r\n".encode() + pcm + b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
        except (BrokenPipeError, ConnectionResetError):
            LOGGER.info("client disconnected mid-stream")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8880)
    parser.add_argument(
        "--model-dir",
        required=True,
        type=Path,
        help="directory holding config.json, kokoro-v1_0.pth and voices/*.pt",
    )
    parser.add_argument("--voice", default="af_heart", help="voice used when a request names none or an unknown one")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)
    try:
        synthesizer = Synthesizer(args.model_dir, args.voice)
    except ValueError as error:
        parser.error(str(error))
    server = SpeechServer((args.host, args.port), synthesizer)
    LOGGER.info("serving Kokoro (default voice %s) on http://%s:%d/v1", args.voice, args.host, args.port)
    server.serve_forever()


if __name__ == "__main__":
    main()
