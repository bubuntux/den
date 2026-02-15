{ self, ... }:
{
  flake.nixosModules.profile-work =
    { pkgs, lib, ... }:
    let
      work-run = pkgs.writeShellScriptBin "work-run" ''
        sudo systemctl start container@work.service
        exec machinectl shell juliogm@work /bin/sh -l -c "$*"
      '';
      workExec = cmd: "${work-run}/bin/work-run ${cmd}";
    in
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
      security.sudo.extraRules = [
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
          "nvidia0" = {
            hostPath = "/dev/nvidia0";
            mountPoint = "/dev/nvidia0";
            isReadOnly = false;
          };
          "nvidiactl" = {
            hostPath = "/dev/nvidiactl";
            mountPoint = "/dev/nvidiactl";
            isReadOnly = false;
          };
          "nvidia-modeset" = {
            hostPath = "/dev/nvidia-modeset";
            mountPoint = "/dev/nvidia-modeset";
            isReadOnly = false;
          };
          "nvidia-uvm" = {
            hostPath = "/dev/nvidia-uvm";
            mountPoint = "/dev/nvidia-uvm";
            isReadOnly = false;
          };
          "nvidia-uvm-tools" = {
            hostPath = "/dev/nvidia-uvm-tools";
            mountPoint = "/dev/nvidia-uvm-tools";
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
            hostPath = "/home/leo/work";
            mountPoint = "/home/juliogm";
            isReadOnly = false;
          };
          "host_home" = {
            hostPath = "/home/leo";
            mountPoint = "/host_home";
            isReadOnly = false;
          };
        };

        config =
          { pkgs, ... }:
          {
            nixpkgs.config = {
              allowUnfree = true;
              google-chrome.commandLineArgs = "--enable-features=UseOzonePlatform,WebRTCPipeWireCapturer --ozone-platform=wayland";
            };

            services = {
              resolved.enable = false;
              cloudflare-warp.enable = true;
              pipewire.enable = lib.mkForce false;
              pulseaudio.enable = lib.mkForce false;
            };

            users.users.juliogm = {
              isNormalUser = true;
              uid = 1000;
              extraGroups = [
                "audio"
                "network"
                "pipewire"
                "video"
                "wheel"
              ];
              home = "/home/juliogm";
              createHome = true;
            };

            environment.systemPackages = with pkgs; [
              cloudflare-warp
              jetbrains.gateway
              (symlinkJoin {
                name = "google-chrome";
                paths = [ google-chrome ];
                postBuild = ''
                  ln -s $out/bin/google-chrome-stable $out/bin/google-chrome
                '';
              })
              slack
              zoom-us

              claude-code
              git

              v4l-utils
              libv4l
              gst_all_1.gstreamer
              gst_all_1.gst-plugins-base
              gst_all_1.gst-plugins-good
              gst_all_1.gst-plugins-bad

              pulseaudio
              noto-fonts
              pipewire

              qt5.qtwayland
              qt6.qtwayland

              xdg-desktop-portal
              xdg-desktop-portal-wlr
              xdg-desktop-portal-gtk
            ];

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

            programs.nix-ld.enable = true;
            programs.nix-ld.libraries = with pkgs; [
              acl
              alsa-lib
              atk
              at-spi2-atk
              at-spi2-core
              attr
              bzip2
              cairo
              coreutils
              cups
              curl
              dbus
              dbus-glib
              e2fsprogs
              expat
              ffmpeg
              flac
              fontconfig
              freeglut
              freetype
              fuse
              gdk-pixbuf
              glew110
              glib
              gsettings-desktop-schemas
              gtk2
              gtk3
              icu
              libappindicator-gtk2
              libcaca
              libcanberra
              libcap
              libdbusmenu-gtk2
              libdrm
              libelf
              libgbm
              libgcrypt
              libGL
              libGLU
              libglvnd
              libidn
              libidn2
              libindicator-gtk2
              libjpeg
              libmikmod
              libnotify
              libogg
              libpng
              libpng12
              librsvg
              libsamplerate
              libsodium
              libssh
              libtheora
              libtiff
              libudev0-shim
              libusb1
              libva
              libvdpau
              libvorbis
              libvpx
              libxcb
              libxcrypt
              libxcrypt-legacy
              libxkbcommon
              libxml2
              mesa
              networkmanager
              nspr
              nss
              openssl
              pango
              pciutils
              pipewire
              pixman
              qt5.qtwayland
              qt6.qtwayland
              SDL
              SDL2
              SDL2_image
              SDL2_mixer
              SDL2_ttf
              SDL_image
              SDL_mixer
              SDL_ttf
              speex
              stdenv.cc.cc
              stdenv.cc.cc.lib
              systemd
              tbb
              util-linux
              vulkan-loader
              wayland
              xorg.libICE
              xorg.libSM
              xorg.libX11
              xorg.libxcb
              xorg.libXcomposite
              xorg.libXcursor
              xorg.libXdamage
              xorg.libXext
              xorg.libXfixes
              xorg.libXft
              xorg.libXi
              xorg.libXinerama
              xorg.libxkbfile
              xorg.libXmu
              xorg.libXrandr
              xorg.libXrender
              xorg.libXScrnSaver
              xorg.libxshmfence
              xorg.libXt
              xorg.libXtst
              xorg.libXxf86vm
              xz
              zenity
              zlib
              zstd
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

            system.stateVersion = "25.11";
          };
      };

      # Webcam support for container
      systemd.services."container@work" = {
        serviceConfig = {
          DeviceAllow = [
            "char-drm rwm"
            "char-video4linux rwm"
            "char-misc rwm"
          ];
        };
        preStart = ''
          mkdir -p /run/systemd/nspawn
          echo "[Files]" > /run/systemd/nspawn/work.nspawn
          for dev in /dev/video*; do
            if [ -e "$dev" ]; then
              echo "Bind=$dev" >> /run/systemd/nspawn/work.nspawn
            fi
          done
        '';
      };

      # Home Manager configuration for work aliases and desktop entries
      home-manager.sharedModules = [
        (
          { pkgs, ... }:
          {
            home = {
              shellAliases = {
                work = "sudo systemctl start container@work.service && machinectl shell juliogm@work";
                cvm = workExec "ssh cvm";
                ben = workExec "ssh ben";
                bensync = workExec "rsync -razvP juliogm@juliogm-ben.cvm.indeed.net:vllm_* benchmarks/";
              };
              packages = with pkgs; [
                work-run
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
                  name = "zoom-work";
                  desktopName = "Zoom (Work)";
                  exec = workExec "zoom";
                  icon = "Zoom";
                  categories = [
                    "Network"
                    "VideoConference"
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
          }
        )
      ];
    };
}
