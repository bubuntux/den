{ pkgs, ... }:
let
  work-run = pkgs.writeShellScriptBin "work-run" ''
    sudo systemctl start container@work.service
    exec machinectl -q shell juliogm@work /bin/sh -l -c "$*"
  '';
  workExec = cmd: "${work-run}/bin/work-run ${cmd}";
  # Unlike work-run, does not boot a stopped container just to stop voice.
  stop-voice-work = pkgs.writeShellScriptBin "stop-voice-work" ''
    exec machinectl -q shell juliogm@work /bin/sh -l -c "systemctl --user stop voicemode.target"
  '';
  # Host-side handler for a deep link (slack://, zoommtg://, ...) clicked
  # anywhere on the host — including container-Chrome, which routes OpenURI
  # through the shared host session bus to the host portal. Run the
  # container command, forwarding the URL as its own argv element through a
  # login shell so the container inherits the session env (WAYLAND_DISPLAY,
  # DBUS, ...) and the URL's `&` query separators aren't chewed up by sh.
  mkUriOpener =
    name: cmd:
    pkgs.writeShellScriptBin name ''
      sudo systemctl start container@work.service
      url="''${1:-}"
      if [ -n "$url" ]; then
        exec machinectl -q shell juliogm@work /bin/sh -l -c 'exec ${cmd} "$1"' ${name} "$url"
      else
        exec machinectl -q shell juliogm@work /bin/sh -l -c 'exec ${cmd}'
      fi
    '';
  # Both Slack and Zoom live only in the container.
  slack-work-open = mkUriOpener "slack-work-open" "slack";
  zoom-work-open = mkUriOpener "zoom-work-open" "zoom-work";
  # The WARP enrollment token comes back as a com.cloudflare.warp:// link,
  # and warp-cli itself is what consumes it. --accept-tos because there is
  # no terminal here to answer the prompt.
  warp-work-open = mkUriOpener "warp-work-open" "warp-cli --accept-tos registration token";
in
{
  key = "den:homeManager.work-container";
  home = {
    shellAliases = {
      work = "sudo systemctl start container@work.service && machinectl -q shell juliogm@work";
      cvm = workExec "ssh-cvm";
    };
    packages = with pkgs; [
      work-run
      (makeDesktopItem {
        name = "slack-work";
        desktopName = "Slack (Work)";
        exec = "${slack-work-open}/bin/slack-work-open %u";
        icon = "slack";
        categories = [
          "Network"
          "InstantMessaging"
          "Chat"
        ];
        # Make this the slack:// handler so deep links open the container Slack
        mimeTypes = [ "x-scheme-handler/slack" ];
      })
      (makeDesktopItem {
        name = "zoom-work";
        desktopName = "Zoom (Work)";
        exec = "${zoom-work-open}/bin/zoom-work-open %u";
        icon = "Zoom";
        categories = [ "Network" ];
        mimeTypes = [
          "x-scheme-handler/zoommtg"
          "x-scheme-handler/zoomus"
        ];
      })
      (makeDesktopItem {
        name = "warp-work";
        desktopName = "Cloudflare Zero Trust Team Enrollment (Work)";
        exec = "${warp-work-open}/bin/warp-work-open %u";
        categories = [ "Network" ];
        mimeTypes = [ "x-scheme-handler/com.cloudflare.warp" ];
        noDisplay = true;
      })
      (makeDesktopItem {
        name = "google-chrome-work";
        desktopName = "Google Chrome (Work)";
        exec = workExec "google-chrome-stable";
        icon = "google-chrome";
        categories = [
          "Network"
          "WebBrowser"
        ];
      })
      (makeDesktopItem {
        name = "Cloud VM";
        desktopName = "Cloud VM (Work)";
        exec = workExec "google-chrome-stable --profile-directory=Default --app-id=dpapjfbeplbjjimcnklbjoibkcaocjhg";
        categories = [
          "Network"
        ];
      })
      (makeDesktopItem {
        name = "stop-work";
        desktopName = "Stop Work";
        exec = "machinectl stop work";
        icon = "process-stop";
        categories = [
          "System"
        ];
      })
      (makeDesktopItem {
        name = "start-voice-work";
        desktopName = "Start Voice (Work)";
        exec = workExec "systemctl --user start voicemode.target";
        icon = "audio-input-microphone";
        categories = [
          "AudioVideo"
        ];
      })
      (makeDesktopItem {
        name = "stop-voice-work";
        desktopName = "Stop Voice (Work)";
        exec = "${stop-voice-work}/bin/stop-voice-work";
        icon = "process-stop";
        categories = [
          "AudioVideo"
        ];
      })
    ];
  };

  # Route slack://, zoom:// and the WARP enrollment callback into the work
  # container.
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/com.cloudflare.warp" = "warp-work.desktop";
    "x-scheme-handler/slack" = "slack-work.desktop";
    "x-scheme-handler/zoommtg" = "zoom-work.desktop";
    "x-scheme-handler/zoomus" = "zoom-work.desktop";
  };
}
