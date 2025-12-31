{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;
    config = {
      ao = "pipewire";
      hwdec = "auto";
      keep-open = "yes";
    };
    defaultProfiles = [ "gpu-hq" ];
    scripts = with pkgs; [
      mpvScripts.mpris
      mpvScripts.sponsorblock
      # mpvScripts.mpv-cheatsheet
      mpvScripts.twitch-chat
      # mpvScripts.youtube-chat
    ];
    profiles = {
      # youtube = {
      #   profile-cond = "get(\"path\", \"\"):find(\"^https://www.youtube.com/\") ~= nil";
      #   profile = "low-latency";
      #   cache = "no";
      #   # vo = "gpu-next";
      #   hwdec = "auto-safe";
      #   demuxer-max-bytes = "150M";
      #   demuxer-max-back-bytes = "100M";
      #   sub-font-size = 30;
      #   sub-align-x = "right";
      #   sub-align-y = "top";
      # };
      twitch = {
        profile-cond = "get(\"path\", \"\"):find(\"^https://www.twitch.tv/\") ~= nil";
        profile = "low-latency";
        cache = "no";
        # vo = "gpu-next";
        hwdec = "auto-safe";
        demuxer-max-bytes = "150M";
        demuxer-max-back-bytes = "100M";
        sub-font-size = 30;
        sub-align-x = "right";
        sub-align-y = "top";
      };
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
      };
      "protocol.http" = {
        profile = "network";
      };
      "protocol.https" = {
        profile = "network";
      };
    };
  };
}
