{
  # Offline voice dictation for sway.
  #
  # Push-to-talk toggle bound to Mod4+grave: press once to start recording the
  # mic, press again to stop -> whisper.cpp transcribes the clip locally and
  # wtype injects the text into the focused window. Fully offline (no cloud STT);
  # every component (pw-record, whisper-cli, wtype) comes from nixpkgs.
  #
  # The keybinding is defined here rather than in the sway bundle's
  # _keybindings.nix so it can reference the `dictate` script by absolute store
  # path -- matching the repo's `exec ${pkgs.foo}/bin/foo` convention (the sway
  # session does not reliably have the home-manager profile on PATH).
  flake.homeModules.dictation =
    { pkgs, ... }:
    let
      # base.en GGML model (~142 MB), fetched and cached at build time. For higher
      # accuracy at the cost of speed/size, swap to ggml-small.en.bin (and refresh
      # the hash via `nix store prefetch-file <url>`).
      whisperModel = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
        hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
      };

      dictate = pkgs.writeShellApplication {
        name = "dictate";
        runtimeInputs = with pkgs; [
          pipewire # pw-record
          whisper-cpp # whisper-cli
          wtype # type into the focused Wayland window
          libnotify # notify-send
          coreutils # nproc, tr, mkdir, rm, sleep
          gnused # sed
        ];
        text = ''
          mode="''${1:-toggle}"
          state="''${XDG_RUNTIME_DIR:-/tmp}/dictate"
          mkdir -p "$state"
          pidfile="$state/rec.pid"
          wav="$state/rec.wav"

          notify() {
            notify-send -t "$1" -h string:x-canonical-private-synchronous:dictate "$2" "$3"
          }

          is_recording() {
            local pid
            [ -f "$pidfile" ] || return 1
            read -r pid < "$pidfile" || return 1
            kill -0 "$pid" 2>/dev/null
          }

          start() {
            # 16 kHz mono s16 WAV is exactly what whisper.cpp expects (no resample).
            pw-record --rate 16000 --channels 1 --format s16 "$wav" >/dev/null 2>&1 &
            echo "$!" > "$pidfile"
            disown
            notify 0 "🎙 Recording" "Speak now — trigger dictation again to transcribe."
          }

          stop_and_type() {
            local pid text tries
            read -r pid < "$pidfile"
            kill -INT "$pid" 2>/dev/null || true
            # Wait up to ~5s for pw-record to flush and finalize the WAV header.
            tries=0
            while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt 50 ]; do
              sleep 0.1
              tries=$((tries + 1))
            done
            rm -f "$pidfile"

            notify 3000 "⏳ Transcribing" "Running Whisper locally…"
            if ! whisper-cli -m ${whisperModel} -f "$wav" -nt -l en -t "$(nproc)" \
                 >"$state/out.txt" 2>/dev/null; then
              rm -f "$wav"
              notify 2500 "⚠ Dictation" "Transcription failed."
              exit 1
            fi
            text="$(tr '\n' ' ' <"$state/out.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            rm -f "$wav" "$state/out.txt"

            if [ -z "$text" ] || [ "$text" = "[BLANK_AUDIO]" ]; then
              notify 2000 "🎙 Dictation" "No speech detected."
              exit 0
            fi

            notify 2500 "✓ Dictation" "$text"
            wtype "$text"
          }

          case "$mode" in
            toggle) if is_recording; then stop_and_type; else start; fi ;;
            start) is_recording || start ;;
            stop) if is_recording; then stop_and_type; fi ;;
            *)
              echo "usage: dictate [toggle|start|stop]" >&2
              exit 2
              ;;
          esac
        '';
      };
    in
    {
      home.packages = [ dictate ];

      # Toggle: press to start recording, press again to transcribe + type.
      wayland.windowManager.sway.config.keybindings = {
        "Mod4+grave" = "exec ${dictate}/bin/dictate toggle";
      };
    };
}
