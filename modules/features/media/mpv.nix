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
          ao = "pipewire";
          hwdec = "auto-safe";
          keep-open = "yes";
        };
        defaultProfiles = [ "gpu-next" ];
        scripts = with pkgs; [
          mpvScripts.mpris
          mpvScripts.sponsorblock
        ];
        profiles = {
          big-cache = {
            cache = "yes";
            demuxer-max-bytes = "512MiB";
            demuxer-readahead-secs = 20;
          };
          network = {
            profile = [
              "big-cache"
              "fast"
            ];
            demuxer-max-back-bytes = "256MiB";
            ytdl-format = "bestvideo[height<=1080]+bestaudio/best[height<=1080]";
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
