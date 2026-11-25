{ self, ... }:
{
  flake.modules = {
    homeManager.work-container = import ./_desktop.nix;

    nixos.work-container =
      {
        lib,
        config,
        ...
      }:
      let
        # Host user that owns the container's home mount. The uid is pinned here
        # rather than on the account because it is this module that needs it at
        # evaluation time -- for the session-socket path and the container user
        # below -- and no other host has a reason to fix bbtux to a number.
        workUser = "bbtux";
        workUid = 1000;
        workHome = config.users.users.${workUser}.home;
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
        hasNvidia = config.hardware.nvidia.enabled;
        nvidiaDevices = [
          "/dev/nvidia0"
          "/dev/nvidiactl"
          "/dev/nvidia-modeset"
          "/dev/nvidia-uvm"
        ];
      in
      {
        key = "den:nixos.work-container";

        # NixOS never renumbers an existing account -- it warns and keeps the old
        # uid -- so this only lands on a host where bbtux is new or already 1000.
        users.users.${workUser}.uid = workUid;

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
        sops.secrets =
          lib.genAttrs
            [
              "ssh_config"
              "git_config"
              "jj_config"
              "ssh_private_key"
              "ssh_public_key"
              "voicemode_serve_token"
            ]
            (_: {
              sopsFile = "${self}/secrets/juliogm.yaml";
              owner = workUser;
            });

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
            "voicemode-serve-token" = {
              hostPath = config.sops.secrets.voicemode_serve_token.path;
              mountPoint = "/run/secrets-host/voicemode_serve_token";
              isReadOnly = true;
            };
            "localtime" = {
              hostPath = "/etc/localtime";
              mountPoint = "/etc/localtime";
              isReadOnly = true;
            };
          }
          // lib.optionalAttrs hasNvidia (
            lib.genAttrs nvidiaDevices (device: {
              hostPath = device;
              isReadOnly = false;
            })
          );

          config = import ./_guest.nix {
            inherit
              self
              lib
              workUid
              workHome
              workDir
              workRuntimeDir
              hostSessionDir
              hasNvidia
              ;
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
            ]
            ++ lib.optionals hasNvidia [
              "char-nvidia rwm"
              "char-nvidia-uvm rwm"
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
