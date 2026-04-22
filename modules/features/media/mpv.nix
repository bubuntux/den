{
  flake.homeModules.mpv =
    { pkgs, ... }:
    {
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
