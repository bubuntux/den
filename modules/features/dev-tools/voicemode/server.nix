_: {
  flake.modules.homeManager.voicemode-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.den.voicemode.server;

      voicemode = pkgs.callPackage ./_voicemode.nix { };
      kokoro-openai-server = pkgs.callPackage ./_kokoro-openai-server.nix { };

      whisperModel = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo-q5_0.bin";
        hash = "sha256-OUIhcJzVrR9AxG5gMcphvOiJMebgiMGIKUxtWlX/p+I=";
      };

      # VoiceMode's own defaults: it tells Kokoro from any other speech
      # endpoint by the port alone.
      ports = {
        whisper = 2022;
        kokoro = 8880;
        serve = 8765;
      };

      environment = lib.mapAttrsToList (name: value: "${name}=${value}") cfg.environment;

      memberOfTarget = description: {
        Description = description;
        PartOf = [ "voicemode.target" ];
      };

      serve = pkgs.writeShellScript "voicemode-serve" ''
        VOICEMODE_SERVE_TOKEN=$(< ${lib.escapeShellArg cfg.tokenFile})
        export VOICEMODE_SERVE_TOKEN
        exec ${lib.getExe voicemode} serve --host 127.0.0.1 --port ${toString ports.serve}
      '';
    in
    {
      key = "den:homeManager.voicemode-server";

      options.den.voicemode.server = {
        tokenFile = lib.mkOption {
          type = lib.types.str;
          description = ''
            File holding the bearer token every MCP client must present. The
            endpoint drives this machine's microphone, and anyone who can reach
            its port -- including other users on a host it is tunnelled to --
            gets that without it.
          '';
        };

        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            PULSE_SERVER = "unix:/mnt/host-session/pulse/native";
            VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
          };
          description = ''
            Extra environment for every VoiceMode unit: where the audio server
            is, when it is not in this user's runtime directory, and which
            Vulkan driver whisper runs on. Left unset, whisper takes the first
            GPU Vulkan reports, which on a hybrid laptop is the integrated one.
          '';
        };
      };

      config.systemd.user = {
        targets.voicemode.Unit.Description = "VoiceMode: speech-to-text, text-to-speech and the MCP endpoint";

        services = {
          voicemode-whisper = {
            Unit = memberOfTarget "VoiceMode speech-to-text (whisper.cpp)";
            Service = {
              ExecStart = lib.escapeShellArgs [
                (lib.getExe' pkgs.whisper-cpp-vulkan "whisper-server")
                "--host"
                "127.0.0.1"
                "--port"
                (toString ports.whisper)
                "--model"
                "${whisperModel}"
                "--language"
                "en"
                "--inference-path"
                "/v1/audio/transcriptions"
                "--convert"
              ];
              Environment = environment ++ [ "PATH=${lib.makeBinPath [ pkgs.ffmpeg ]}" ];
              Restart = "on-failure";
            };
            Install.WantedBy = [ "voicemode.target" ];
          };

          voicemode-kokoro = {
            Unit = memberOfTarget "VoiceMode text-to-speech (Kokoro)";
            Service = {
              ExecStart = lib.escapeShellArgs [
                (lib.getExe kokoro-openai-server)
                "--host"
                "127.0.0.1"
                "--port"
                (toString ports.kokoro)
              ];
              Environment = environment;
              Restart = "on-failure";
            };
            Install.WantedBy = [ "voicemode.target" ];
          };

          voicemode-serve = {
            Unit = memberOfTarget "VoiceMode MCP endpoint" // {
              After = [
                "voicemode-kokoro.service"
                "voicemode-whisper.service"
              ];
            };
            Service = {
              ExecStart = "${serve}";
              Environment = environment ++ [
                "VOICEMODE_STT_BASE_URLS=http://127.0.0.1:${toString ports.whisper}/v1"
                "VOICEMODE_TTS_BASE_URLS=http://127.0.0.1:${toString ports.kokoro}/v1"
                "VOICEMODE_VOICES=af_heart"
              ];
              Restart = "on-failure";
            };
            Install.WantedBy = [ "voicemode.target" ];
          };
        };
      };
    };
}
