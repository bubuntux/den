let
  mimeDefaults = builtins.listToAttrs (
    map
      (m: {
        name = m;
        value = "mpv.desktop";
      })
      [
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/mpeg"
        "video/quicktime"
        "video/x-msvideo"
        "video/x-flv"
        "video/ogg"
        "video/3gpp"
        "video/3gpp2"
        "audio/mpeg"
        "audio/flac"
        "audio/ogg"
        "audio/x-vorbis+ogg"
        "audio/opus"
        "audio/x-opus+ogg"
        "audio/aac"
        "audio/mp4"
        "audio/m4a"
        "audio/x-m4a"
        "audio/wav"
        "audio/x-wav"
        "audio/x-matroska"
      ]
  );
in
{
  flake.homeModules.mpv =
    { pkgs, ... }:
    {
      xdg.mimeApps.defaultApplications = mimeDefaults;

      programs.mpv = {
        enable = true;
        package = pkgs.mpv;
        config = {
          vo = "gpu-next"; # libplacebo video output (not a profile)
          ao = "pipewire";
          hwdec = "auto-safe";
          keep-open = "yes";
          # uosc replaces the built-in OSC; disable both to avoid overlap.
          osc = "no";
          osd-bar = "no";
        };
        scripts = with pkgs; [
          mpvScripts.mpris
          mpvScripts.sponsorblock
          mpvScripts.reload # auto-reload the stream on a stall/EOF
          mpvScripts.chapterskip # auto-skip intro/outro/sponsor chapters
          mpvScripts.uosc # modern OSC with menus and chapter markers
          mpvScripts.thumbfast # seekbar thumbnail previews (used by uosc)
        ];
        profiles = {
          big-cache = {
            cache = "yes";
            # Spill the cache to disk: cache whole long videos, scrub backward
            # without re-downloading, and survive long network drops.
            cache-on-disk = "yes";
            demuxer-max-bytes = "512MiB";
            demuxer-max-back-bytes = "256MiB";
            # Burst-fill the cache instead of topping up continuously, so the
            # Wi-Fi radio can idle between reads. cache-secs governs read-ahead.
            demuxer-hysteresis-secs = 30;
          };
          network = {
            profile = [
              "big-cache"
              "fast"
            ];
            # Fast start: begin playback before prefilling, keep buffering ahead,
            # and resume quickly after a stall.
            cache-pause-initial = "no";
            cache-secs = 120;
            cache-pause-wait = 1;
            force-seekable = "yes";
            # Cap at 720p for quick startup; prefer HW-decoded AV1/VP9 on the iGPU.
            ytdl-format = "bestvideo[height<=?720][vcodec^=av01]+bestaudio/bestvideo[height<=?720][vcodec^=vp9]+bestaudio/best[height<=?720]/best";
          };
          # Local files (not streamed) get higher-quality scaling; streams keep `fast`.
          local-quality = {
            profile-cond = "not demuxer_via_network";
            profile-restore = "copy-equal";
            scale = "ewa_lanczossharp";
            cscale = "ewa_lanczossharp";
            deband = "yes";
          };
          "extension.gif" = {
            loop-file = "inf";
          };
          "protocol.http" = {
            profile = "network";
          };
          "protocol.https" = {
            profile = "network";
          };
        };
      };
    };
}
