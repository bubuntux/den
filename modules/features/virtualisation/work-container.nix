{ self, ... }:
{
  flake.homeModules.work-container =
    { pkgs, ... }:
    let
      work-run = pkgs.writeShellScriptBin "work-run" ''
        sudo systemctl start container@work.service
        exec machinectl -q shell juliogm@work /bin/sh -l -c "$*"
      '';
      workExec = cmd: "${work-run}/bin/work-run ${cmd}";
    in
    {
      home = {
        shellAliases = {
          work = "sudo systemctl start container@work.service && machinectl -q shell juliogm@work";
          cvm = workExec "ssh cvm";
        };
        packages = with pkgs; [
          work-run
          # TODO move slack
          slack
          (makeDesktopItem {
            name = "slack-work";
            desktopName = "Slack (Work)";
            exec = workExec "slack";
            icon = "slack";
            categories = [
              "Network"
              "InstantMessaging"
              "Chat"
            ];
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
            name = "gateway-work";
            desktopName = "Gateway (Work)";
            exec = workExec "gateway";
            icon = "jetbrains-gateway";
            categories = [
              "Development"
              "IDE"
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
        ];
      };
    };

  flake.nixosModules.work-container =
    {
      lib,
      config,
      ...
    }:
    {
      # Polkit rules for container management
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.freedesktop.machine1.") == 0 &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      # Sudo rules for starting work container without password
      security.sudo-rs.extraRules = [
        {
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl start container@work.service";
              options = [ "NOPASSWD" ];
            }
          ];
          groups = [ "wheel" ];
        }
      ];

      # Sops secrets for juliogm (decrypted on host, bind-mounted into container)
      sops.secrets.ssh_config = {
        sopsFile = "${self}/secrets/juliogm.yaml";
        owner = "bbtux";
      };
      sops.secrets.git_config = {
        sopsFile = "${self}/secrets/juliogm.yaml";
        owner = "bbtux";
      };
      sops.secrets.ssh_private_key = {
        sopsFile = "${self}/secrets/juliogm.yaml";
        owner = "bbtux";
      };
      sops.secrets.ssh_public_key = {
        sopsFile = "${self}/secrets/juliogm.yaml";
        owner = "bbtux";
      };
      # Network configuration for container
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
      networking.firewall.trustedInterfaces = [ "ve-+" ];
      networking.nftables.ruleset = lib.mkAfter ''
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            ip saddr 192.168.100.11 masquerade
          }
        }
      '';

      # Work container
      containers.work = {
        autoStart = false;
        privateNetwork = true;
        hostAddress = "192.168.100.10";
        localAddress = "192.168.100.11";
        # Needed for bwrap/bubblewrap sandboxing inside the container (used by zoom, chrome)
        additionalCapabilities = [ "CAP_SYS_ADMIN" ];

        bindMounts = {
          "wayland" = {
            hostPath = "/run/user/1000/wayland-1";
            mountPoint = "/mnt/wayland-1";
            isReadOnly = false;
          };
          "pulse" = {
            hostPath = "/run/user/1000/pulse/native";
            mountPoint = "/mnt/pulse";
            isReadOnly = false;
          };
          "pipewire" = {
            hostPath = "/run/user/1000/pipewire-0";
            mountPoint = "/mnt/pipewire-0";
            isReadOnly = false;
          };
          "dbus" = {
            hostPath = "/run/user/1000/bus";
            mountPoint = "/mnt/bus";
            isReadOnly = false;
          };
          "udev" = {
            hostPath = "/run/udev";
            mountPoint = "/run/udev";
            isReadOnly = true;
          };
          "dri" = {
            hostPath = "/dev/dri";
            mountPoint = "/dev/dri";
            isReadOnly = false;
          };
          "opengl-driver" = {
            hostPath = "/run/opengl-driver";
            mountPoint = "/run/opengl-driver";
            isReadOnly = true;
          };
          "shm" = {
            hostPath = "/dev/shm";
            mountPoint = "/dev/shm";
            isReadOnly = false;
          };
          "tun" = {
            hostPath = "/dev/net/tun";
            mountPoint = "/dev/net/tun";
            isReadOnly = false;
          };
          "home" = {
            hostPath = "/home/bbtux/work";
            mountPoint = "/home/juliogm";
            isReadOnly = false;
          };
          "ssh-config" = {
            hostPath = config.sops.secrets.ssh_config.path;
            mountPoint = "/run/secrets-host/ssh_config";
            isReadOnly = true;
          };
          "git-config" = {
            hostPath = config.sops.secrets.git_config.path;
            mountPoint = "/run/secrets-host/git_config";
            isReadOnly = true;
          };
          "ssh-private-key" = {
            hostPath = config.sops.secrets.ssh_private_key.path;
            mountPoint = "/run/secrets-host/ssh_private_key";
            isReadOnly = true;
          };
          "ssh-public-key" = {
            hostPath = config.sops.secrets.ssh_public_key.path;
            mountPoint = "/run/secrets-host/ssh_public_key";
            isReadOnly = true;
          };
          "localtime" = {
            hostPath = "/etc/localtime";
            mountPoint = "/etc/localtime";
            isReadOnly = true;
          };
        };

        config =
          { pkgs, ... }:
          let
            # Translate zoommtg:// / zoomus:// links into the Zoom web client and
            # open them in Chrome as an ad-hoc PWA window (--app=URL).
            zoom-web-open = pkgs.writeShellScriptBin "zoom-web-open" ''
              set -u
              url="''${1:-}"
              confno=""
              pwd=""
              tk=""
              if [ -n "$url" ]; then
                query="''${url#*\?}"
                old_ifs="$IFS"
                IFS='&'
                set -f
                for pair in $query; do
                  k="''${pair%%=*}"
                  v="''${pair#*=}"
                  case "$k" in
                    confno) confno="$v" ;;
                    pwd) pwd="$v" ;;
                    tk) tk="$v" ;;
                  esac
                done
                set +f
                IFS="$old_ifs"
              fi
              if [ -z "$confno" ]; then
                exec google-chrome-stable --app="https://zoom.us/wc/join"
              fi
              target="https://zoom.us/wc/join/$confno"
              sep="?"
              if [ -n "$pwd" ]; then
                target="''${target}''${sep}pwd=''${pwd}"
                sep="&"
              fi
              if [ -n "$tk" ]; then
                target="''${target}''${sep}tk=''${tk}"
              fi
              exec google-chrome-stable --app="$target"
            '';
            zoom-web-desktop = pkgs.makeDesktopItem {
              name = "zoom-web";
              desktopName = "Zoom (Web)";
              exec = "${zoom-web-open}/bin/zoom-web-open %u";
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
            imports = with self.nixosModules; [
              bundle-base
              user-juliogm
            ];

            # WebRtcPipeWireCamera lets Chrome/Zoom-web discover the host's IPU6
            # webcam over the shared PipeWire socket + camera portal (the container
            # has no PipeWire of its own; it uses the host's, like audio/screen-share).
            nixpkgs.config.google-chrome.commandLineArgs = "--enable-features=UseOzonePlatform,WebRTCPipeWireCapturer,WebRtcPipeWireCamera --ozone-platform=wayland";

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

            environment.systemPackages = with pkgs; [
              cloudflare-warp
              jetbrains.gateway
              google-chrome
              slack
              xdg-utils
              zoom-web-open
              zoom-web-desktop

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

            # nix-ld for non-Nix binaries (JetBrains Gateway downloads)
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

              PIPEWIRE_RUNTIME_DIR = "/mnt";
              PIPEWIRE_REMOTE = "unix:/mnt/pipewire-0";
              PULSE_SERVER = "unix:/mnt/pulse";
              DBUS_SESSION_BUS_ADDRESS = "unix:path=/mnt/bus";
              WAYLAND_DISPLAY = "/mnt/wayland-1";
              XDG_RUNTIME_DIR = "/run/user/1000";
            };

            systemd.tmpfiles.rules = [
              "d /run/user/1000 0700 juliogm users -"
              "d /home/juliogm/.ssh 0700 juliogm users -"
              "L+ /home/juliogm/.ssh/id_rsa - - - - /run/secrets-host/ssh_private_key"
              "L+ /home/juliogm/.ssh/id_rsa.pub - - - - /run/secrets-host/ssh_public_key"
              # Symlink so host portal FileChooser paths resolve inside the container
              # (host portal returns /home/bbtux/work/... but container has /home/juliogm/...)
              "d /home/bbtux 0755 juliogm users -"
              "L+ /home/bbtux/work - - - - /home/juliogm"
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

            # Inside the container: Chrome handles URLs, Slack handles slack://,
            # zoom:// links open in Chrome as an ad-hoc PWA window
            home-manager.users.juliogm.xdg.mimeApps.defaultApplications = {
              "text/html" = "google-chrome.desktop";
              "x-scheme-handler/http" = "google-chrome.desktop";
              "x-scheme-handler/https" = "google-chrome.desktop";
              "x-scheme-handler/about" = "google-chrome.desktop";
              "x-scheme-handler/unknown" = "google-chrome.desktop";
              "x-scheme-handler/slack" = "slack.desktop";
              "x-scheme-handler/zoommtg" = "zoom-web.desktop";
              "x-scheme-handler/zoomus" = "zoom-web.desktop";
            };

            system.stateVersion = "25.11";
          };
      };

      # Extra device access for the work container (not camera-related): GPU
      # (/dev/dri, char-drm) for Chrome/Zoom rendering + video decode, and
      # /dev/net/tun (char-misc) for the cloudflare-warp VPN. The webcam reaches
      # the container over the shared host PipeWire socket, so the old /dev/video*
      # bind + char-video4linux access (V4L2 path) are no longer needed.
      systemd.services."container@work".serviceConfig.DeviceAllow = [
        "char-drm rwm"
        "char-misc rwm"
      ];

      # Home Manager configuration for work aliases and desktop entries
      home-manager.sharedModules = [ self.homeModules.work-container ];
    };
}
