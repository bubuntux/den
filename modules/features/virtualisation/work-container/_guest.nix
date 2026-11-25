{
  self,
  lib,
  workUid,
  workHome,
  workDir,
  workRuntimeDir,
  hostSessionDir,
  hasNvidia,
}:
{ pkgs, ... }:
let
  # Reaching cvm from the host terminal, with that terminal's own
  # terminfo -- ghostty's ssh-terminfo feature cannot see this ssh.
  # See AGENTS.md, "Choosing a terminal".
  ssh-cvm = pkgs.writeShellScriptBin "ssh-cvm" ''
    term=''${TERM:-dumb}
    marker="$HOME/.cache/ssh-cvm/$term"

    if [ ! -e "$marker" ]; then
      # The local lookup is its own step because tic exits 0 on
      # empty input, so a missing local entry would cache a success.
      if terminfo=$(infocmp -0 -x "$term" 2>/dev/null) &&
        printf '%s\n' "$terminfo" |
          ssh cvm "infocmp $term >/dev/null 2>&1 ||
                   { mkdir -p ~/.terminfo && tic -x - 2>/dev/null; }"
      then
        mkdir -p "''${marker%/*}" && : >"$marker"
      else
        echo "ssh-cvm: no $term terminfo on cvm, using xterm-256color" >&2
        exec env TERM=xterm-256color ssh cvm "$@"
      fi
    fi

    exec ssh cvm "$@"
  '';
  # Zoom defaults to XWayland (xcb), which crashes in this pure-Wayland
  # container. Setting xwayland=false and enableWaylandShare=true makes
  # Zoom run natively on Wayland and share screens through the host's
  # xdg-desktop-portal-wlr.
  zoom-work = pkgs.writeShellScriptBin "zoom-work" ''
    conf="$HOME/.config/zoomus.conf"
    mkdir -p "$HOME/.config"
    [ -f "$conf" ] || printf '[General]\n' >"$conf"
    set_conf() {
      if grep -q "^$1=" "$conf"; then
        sed -i "s/^$1=.*/$1=$2/" "$conf"
      else
        printf '\n%s=%s\n' "$1" "$2" >>"$conf"
      fi
    }
    set_conf xwayland false
    set_conf enableWaylandShare true
    set_conf showframewindow false
    exec ${lib.getExe pkgs.unstable.zoom-us} "$@"
  '';
  zoom-work-desktop = pkgs.makeDesktopItem {
    name = "zoom-work";
    desktopName = "Zoom";
    exec = "${zoom-work}/bin/zoom-work %u";
    icon = "Zoom";
    categories = [ "Network" ];
    mimeTypes = [
      "x-scheme-handler/zoommtg"
      "x-scheme-handler/zoomus"
    ];
    noDisplay = true;
  };
in
{
  imports = with self.modules.nixos; [
    bundle-base
    user-juliogm
  ];

  # Align the container user's uid with the host work user so the
  # bind-mounted session sockets and sops secrets (owned by the host
  # uid) are readable inside the container.
  users.users.juliogm.uid = lib.mkForce workUid;

  # Disable pam_lastlog2 for login service — it fails inside nspawn
  # containers and causes machinectl shell sessions to exit immediately
  # TODO: remove once fixed upstream https://github.com/NixOS/nixpkgs/issues/501050
  security.pam.services.login.updateWtmp = lib.mkForce false;

  services = {
    resolved.enable = false;
    cloudflare-warp.enable = true;
    pipewire.enable = lib.mkForce false;
    pulseaudio.enable = lib.mkForce false;
  };

  # Fallback for a container-local xdg-open; the enrollment callback
  # a browser here clicks is answered on the host by warp-work.desktop.
  xdg.mime.defaultApplications."x-scheme-handler/com.cloudflare.warp" =
    "com.cloudflare.WarpCli.desktop";

  environment.systemPackages = with pkgs; [
    cloudflare-warp
    ssh-cvm
    # Chrome uses V4L2 for cameras (the default), so it sees the DroidCam
    # v4l2loopback bound at /dev/video*. (The built-in IPU6 cam is
    # PipeWire/libcamera-only and won't appear here.) Ozone/Wayland comes
    # from NIXOS_OZONE_WL and screen share from xdg-desktop-portal, so no
    # extra commandLineArgs are needed.
    google-chrome
    slack
    xdg-utils
    unstable.zoom-us
    zoom-work
    zoom-work-desktop

    v4l-utils
    libv4l
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad

    pulseaudio
    pipewire

    qt5.qtwayland
    qt6.qtwayland

    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
  ];

  # nix-ld for non-Nix binaries
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    libGL
    freetype
    fontconfig
    libxkbcommon
    wayland
    libx11
    libxrender
    libxext
    glib
    gtk3
    nss
    nspr
    cups
    dbus
    expat
    alsa-lib
  ];

  environment.variables = {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER = "wayland";
    WLR_NO_HARDWARE_CURSORS = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "sway";
    JAVA_TOOL_OPTIONS = "-Dawt.toolkit.name=WLToolkit";

    PIPEWIRE_RUNTIME_DIR = hostSessionDir;
    # libpipewire joins PIPEWIRE_RUNTIME_DIR and PIPEWIRE_REMOTE; a unix: URI breaks direct PipeWire clients.
    PIPEWIRE_REMOTE = "pipewire-0";
    PULSE_SERVER = "unix:${hostSessionDir}/pulse/native";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=${hostSessionDir}/bus";
    XDG_RUNTIME_DIR = workRuntimeDir;
  };

  # WAYLAND_DISPLAY can't join the list above: the host socket's name
  # is only known at runtime. Point it at the one socket in the
  # mounted session dir (an absolute path here, so the container's own
  # XDG_RUNTIME_DIR is left out of it). extraInit runs after
  # environment.variables, and every entry point into the container
  # uses a login shell, so this reaches machinectl sessions and
  # desktop launchers alike. A caller that already exported the
  # variable wins.
  environment.extraInit = ''
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      for socket in ${hostSessionDir}/wayland-[0-9]*; do
        if [ -S "$socket" ]; then
          export WAYLAND_DISPLAY="$socket"
          break
        fi
      done
    fi
  '';

  systemd.tmpfiles.rules = [
    "d ${workRuntimeDir} 0700 juliogm users -"
    "d /home/juliogm/.ssh 0700 juliogm users -"
    "L+ /home/juliogm/.ssh/id_rsa - - - - /run/secrets-host/ssh_private_key"
    "L+ /home/juliogm/.ssh/id_rsa.pub - - - - /run/secrets-host/ssh_public_key"
    # Symlink so host portal FileChooser paths resolve inside the container
    # (host portal returns ${workDir}/... but container has /home/juliogm/...)
    "d ${workHome} 0755 juliogm users -"
    "L+ ${workDir} - - - - /home/juliogm"
  ];

  networking = {
    firewall.enable = false;
    useHostResolvConf = false;
    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
    defaultGateway = "192.168.100.10";
  };

  # PortAudio and simpleaudio only speak ALSA, and the host's audio
  # reaches the container solely as a PulseAudio socket.
  environment.etc."asound.conf".text = ''
    pcm_type.pulse { libs.native = ${pkgs.alsa-plugins}/lib/alsa-lib/libasound_module_pcm_pulse.so ; }
    ctl_type.pulse { libs.native = ${pkgs.alsa-plugins}/lib/alsa-lib/libasound_module_ctl_pulse.so ; }
    pcm.!default { type pulse }
    ctl.!default { type pulse }
  '';

  # VoiceMode's units must outlive whichever shell started them.
  users.users.juliogm.linger = true;

  home-manager.users.juliogm = {
    imports = [ self.modules.homeManager.voicemode-server ];

    den.voicemode.server = {
      tokenFile = "/run/secrets-host/voicemode_serve_token";
      environment = {
        PULSE_SERVER = "unix:${hostSessionDir}/pulse/native";
      }
      // lib.optionalAttrs hasNvidia {
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
      };
    };

    # cvm cannot reach the container, so the container dials out and
    # lends cvm its MCP port.
    systemd.user.services.voicemode-tunnel = {
      Unit = {
        Description = "VoiceMode MCP endpoint, forwarded to cvm";
        PartOf = [ "voicemode.target" ];
        After = [ "voicemode-serve.service" ];
      };
      Service = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgs.openssh)
          "-N"
          "-o"
          "BatchMode=yes"
          "-o"
          "ExitOnForwardFailure=yes"
          "-o"
          "ServerAliveInterval=30"
          "-o"
          "ServerAliveCountMax=3"
          "-R"
          "8765:127.0.0.1:8765"
          "cvm"
        ];
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = [ "voicemode.target" ];
    };

    # Inside the container: Chrome handles URLs, Slack handles slack://,
    # zoom:// links open the native Zoom client
    xdg.mimeApps.defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
      "x-scheme-handler/slack" = "slack.desktop";
      "x-scheme-handler/zoommtg" = "zoom-work.desktop";
      "x-scheme-handler/zoomus" = "zoom-work.desktop";
    };
  };

  system.stateVersion = "25.11";
}
