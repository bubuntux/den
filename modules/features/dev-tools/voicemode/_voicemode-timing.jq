# Per-phase timings from a VoiceMode exchanges_<date>.jsonl, read with jq -s.

def median:
  sort
  | if length == 0 then null
    elif length % 2 == 1 then .[length / 2 | floor]
    else (.[length / 2 - 1] + .[length / 2]) / 2
    end;

# strptime has no fractional seconds and wants the offset without a colon.
def epoch:
  .timestamp
  | ((capture("\\.(?<fraction>[0-9]+)").fraction // "0") | "0." + . | tonumber) as $fraction
  | sub("\\.[0-9]+"; "")
  | sub("(?<hours>[+-][0-9]{2}):(?<minutes>[0-9]{2})$"; "\(.hours)\(.minutes)")
  | strptime("%Y-%m-%dT%H:%M:%S%z")
  | mktime + $fraction;

def rounded: if . == null then "-" else . * 100 | round / 100 end;

def row($phase; $seconds): [$phase, ($seconds | length), ($seconds | median | rounded), ($seconds | max | rounded)];

# A reply is logged once it has finished playing, so the gap from your words to
# that entry also holds its first-audio wait and its playback. Gaps over two
# minutes are you walking away, not Claude thinking.
def claude_thinking:
  group_by(.conversation_id)[]
  | sort_by(epoch)
  | [.[:-1], .[1:]]
  | transpose[]
  | select(.[0].type == "stt" and .[1].type == "tts")
  | ((.[1] | epoch) - (.[0] | epoch)) as $gap
  | select($gap < 120)
  | $gap - (.[1].metadata.time_to_first_audio // 0) - (.[1].metadata.playback_time // 0);

. as $exchanges
| [ "phase", "turns", "median s", "max s" ],
  row("you speaking, plus the silence wait"; [ $exchanges[] | select(.type == "stt") | .metadata.timing // "" | capture("record (?<seconds>[0-9.]+)s").seconds | tonumber ]),
  row("whisper speech-to-text"; [ $exchanges[] | select(.type == "stt") | .metadata.transcription_time // empty ]),
  row("Claude thinking"; [ $exchanges | claude_thinking ]),
  row("Kokoro first audio"; [ $exchanges[] | select(.type == "tts") | .metadata.time_to_first_audio // empty ]),
  row("Kokoro whole reply"; [ $exchanges[] | select(.type == "tts") | .metadata.generation_time // empty ])
| @tsv
