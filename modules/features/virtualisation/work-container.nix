{ self, ... }:
{
  flake.modules = {
    homeManager.work-container =
      { pkgs, ... }:
      let
        work-run = pkgs.writeShellScriptBin "work-run" ''
          sudo systemctl start container@work.service
          exec machinectl -q shell juliogm@work /bin/sh -l -c "$*"
        '';
        workExec = cmd: "${work-run}/bin/work-run ${cmd}";
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
        # Slack lives only in the container; zoom:// links open the Zoom web
        # client as a Chrome --app window via the container's zoom-web-open.
        slack-work-open = mkUriOpener "slack-work-open" "slack";
        zoom-work-open = mkUriOpener "zoom-work-open" "zoom-web-open";
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
              # Handle zoom:// deep links: open the Zoom web client as a Chrome
              # --app window inside the container. Hidden from the app menu.
              mimeTypes = [
                "x-scheme-handler/zoommtg"
                "x-scheme-handler/zoomus"
              ];
              noDisplay = true;
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

        # Route slack://, zoom:// and the WARP enrollment callback into the work
        # container.
        xdg.mimeApps.defaultApplications = {
          "x-scheme-handler/com.cloudflare.warp" = "warp-work.desktop";
          "x-scheme-handler/slack" = "slack-work.desktop";
          "x-scheme-handler/zoommtg" = "zoom-work.desktop";
          "x-scheme-handler/zoomus" = "zoom-work.desktop";
        };
      };

    nixos.work-container =
      {
        lib,
        config,
        ...
      }:
      let
        # Host user that owns the container's home mount. The home directory and
        # uid are derived from the user config rather than hardcoded, so the
        # container's socket paths, home mount and secret ownership line up with
        # whatever uid this account has on the host running the module.
        workUser = "bbtux";
        workHome = config.users.users.${workUser}.home;
        workUid = config.users.users.${workUser}.uid;
        workDir = "${workHome}/work";
        # Host user's XDG runtime dir, where the graphical session sockets live.
        workRuntimeDir = "/run/user/${toString workUid}";
        # Where that runtime dir is mounted inside the container. Mounted whole
        # rather than socket-by-socket: the compositor picks its socket name with
        # wl_display_add_socket_auto, so it is wayland-0 on one boot and
        # wayland-1 on the next, and a per-socket bind also goes stale whenever
        # the compositor restarts. The container keeps its own XDG_RUNTIME_DIR;
        # this is only the window onto the host session.
        hostSessionDir = "/mnt/host-session";
      in
      {
        key = "den:nixos.work-container";
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
          owner = workUser;
        };
        sops.secrets.git_config = {
          sopsFile = "${self}/secrets/juliogm.yaml";
          owner = workUser;
        };
        sops.secrets.jj_config = {
          sopsFile = "${self}/secrets/juliogm.yaml";
          owner = workUser;
        };
        sops.secrets.ssh_private_key = {
          sopsFile = "${self}/secrets/juliogm.yaml";
          owner = workUser;
        };
        sops.secrets.ssh_public_key = {
          sopsFile = "${self}/secrets/juliogm.yaml";
          owner = workUser;
        };
        # Ensure the container's home mount point exists on the host
        systemd.tmpfiles.rules = [
          "d ${workDir} 0755 ${workUser} users -"
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
          # Needed for bwrap/bubblewrap sandboxing inside the container (used by zoom, chrome)
          additionalCapabilities = [ "CAP_SYS_ADMIN" ];

          bindMounts = {
            # Wayland, PipeWire, PulseAudio and the session bus in one mount.
            "host-session" = {
              hostPath = workRuntimeDir;
              mountPoint = hostSessionDir;
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
              hostPath = workDir;
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
            "jj-config" = {
              hostPath = config.sops.secrets.jj_config.path;
              mountPoint = "/run/secrets-host/jj_config";
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
              # Reaching cvm from the host terminal, with that terminal's own
              # terminfo -- ghostty's ssh-terminfo feature cannot see this ssh.
              # See CLAUDE.md, "Choosing a terminal".
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
                jetbrains.gateway
                ssh-cvm
                # Chrome uses V4L2 for cameras (the default), so it sees the DroidCam
                # v4l2loopback bound at /dev/video*. (The built-in IPU6 cam is
                # PipeWire/libcamera-only and won't appear here.) Ozone/Wayland comes
                # from NIXOS_OZONE_WL and screen share from xdg-desktop-portal, so no
                # extra commandLineArgs are needed.
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

                PIPEWIRE_RUNTIME_DIR = hostSessionDir;
                PIPEWIRE_REMOTE = "unix:${hostSessionDir}/pipewire-0";
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

        # Webcam support for container: bind the host /dev/video* nodes (incl. the
        # DroidCam v4l2loopback camera) into the container, plus GPU (char-drm) and
        # /dev/net/tun (char-misc, for cloudflare-warp). Chrome enumerates these via
        # V4L2 and uses the DroidCam loopback directly.
        systemd.services."container@work" = {
          serviceConfig = {
            DeviceAllow = [
              "char-drm rwm"
              "char-video4linux rwm"
              "char-misc rwm"
            ];
            EnvironmentFile = lib.mkForce [ "-/run/nixos-containers/work.conf" ];
          };
          preStart = ''
            VIDEO_FLAGS=""
            for dev in /dev/video*; do
              if [ -e "$dev" ]; then
                VIDEO_FLAGS="$VIDEO_FLAGS --bind=$dev"
              fi
            done
            mkdir -p /run/nixos-containers
            cp -fL /etc/nixos-containers/work.conf /run/nixos-containers/work.conf
            if [ -n "$VIDEO_FLAGS" ]; then
              sed -i "s|^EXTRA_NSPAWN_FLAGS=\"|EXTRA_NSPAWN_FLAGS=\"$VIDEO_FLAGS |" /run/nixos-containers/work.conf
            fi
          '';
        };

        # Home Manager configuration for work aliases and desktop entries
        home-manager.sharedModules = [ self.modules.homeManager.work-container ];
      };
  };
}
