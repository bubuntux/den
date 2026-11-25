{ self, ... }:
{
  flake.modules.nixos.immich-ml =
    { lib, pkgs, ... }:
    let
      port = 3003;
      cacheDir = "/var/cache/immich-ml";
      unit = "podman-immich-ml.service";

      immich-ml-ctl = pkgs.writeShellApplication {
        name = "immich-ml-ctl";
        runtimeInputs = [
          pkgs.libnotify
          pkgs.systemd
        ];
        text = ''
          notify() {
            notify-send -h string:x-canonical-private-synchronous:immich-ml "Immich ML" "$1"
          }

          start_unit() {
            if systemctl is-active --quiet "${unit}"; then
              notify "Already running on port ${toString port}"
              return 0
            fi
            notify "Starting on RTX GPU (first run pulls image)..."
            if systemctl start "${unit}"; then
              notify "Running on port ${toString port}"
            else
              notify "Failed to start — check journalctl -u ${unit}"
              exit 1
            fi
          }

          stop_unit() {
            if ! systemctl is-active --quiet "${unit}"; then
              notify "Already stopped"
              return 0
            fi
            notify "Stopping..."
            if systemctl stop "${unit}"; then
              notify "Stopped"
            else
              notify "Failed to stop ${unit}"
              exit 1
            fi
          }

          case "''${1:-toggle}" in
            start) start_unit ;;
            stop) stop_unit ;;
            toggle)
              if systemctl is-active --quiet "${unit}"; then
                stop_unit
              else
                start_unit
              fi
              ;;
            *)
              echo "usage: immich-ml-ctl [start|stop|toggle]" >&2
              exit 2
              ;;
          esac
        '';
      };

      mkDesktop =
        {
          action,
          label,
          comment,
          icon,
        }:
        pkgs.makeDesktopItem {
          name = "immich-ml-${action}";
          desktopName = "${label} Immich Worker";
          inherit comment icon;
          exec = "${lib.getExe immich-ml-ctl} ${action}";
          categories = [ "Utility" ];
        };

      desktopItems = map mkDesktop [
        {
          action = "toggle";
          label = "Toggle";
          comment = "Start or stop the local Immich CUDA machine learning worker";
          icon = "applications-science";
        }
        {
          action = "start";
          label = "Start";
          comment = "Start the local Immich CUDA machine learning worker";
          icon = "media-playback-start";
        }
        {
          action = "stop";
          label = "Stop";
          comment = "Stop the local Immich CUDA machine learning worker";
          icon = "media-playback-stop";
        }
      ];
    in
    {
      key = "den:nixos.immich-ml";
      imports = [ self.modules.nixos.podman ];

      virtualisation.oci-containers.containers.immich-ml = {
        # On-demand: avoid running a CUDA container on boot or battery.
        autoStart = false;
        # Pin to the unstable immich version appa runs so server and ML never drift.
        image = "ghcr.io/immich-app/immich-machine-learning:v${pkgs.unstable.immich.version}-cuda";
        ports = [ "${toString port}:${toString port}" ];
        volumes = [ "${cacheDir}:/cache" ];
        environment = {
          IMMICH_PORT = toString port;
          MACHINE_LEARNING_CACHE_FOLDER = "/cache";
          # Unload models quickly when idle so PRIME finegrained power management
          # puts the RTX dGPU back to sleep.
          MACHINE_LEARNING_MODEL_TTL = "60";
          MACHINE_LEARNING_WORKERS = "1";
        };
        extraOptions = [
          "--device=nvidia.com/gpu=all"
        ];
      };

      systemd.tmpfiles.rules = [
        "d ${cacheDir} 0755 root root - -"
      ];

      # Yield to interactive workstation/gaming loads, and wait for CDI generation.
      systemd.services.podman-immich-ml = {
        after = [ "nvidia-container-toolkit-cdi-generator.service" ];
        wants = [ "nvidia-container-toolkit-cdi-generator.service" ];
        serviceConfig = {
          Nice = 10;
          CPUWeight = 50;
          IOWeight = 50;
        };
      };

      # Allow wheel users to toggle the unit from the .desktop launcher without a password prompt.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "${unit}" &&
              subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      environment.systemPackages = [ immich-ml-ctl ] ++ desktopItems;

      # zuko is a laptop: only accept Immich ML requests from trusted LAN ranges.
      networking.firewall.extraInputRules = ''
        ip saddr { ${lib.concatStringsSep ", " self.lib.lan.ipv4} } tcp dport ${toString port} accept
        ip6 saddr { ${lib.concatStringsSep ", " self.lib.lan.ipv6} } tcp dport ${toString port} accept
      '';

      virtualisation.vmVariant.virtualisation.oci-containers.containers.immich-ml.extraOptions =
        lib.mkForce
          [ ];
    };
}
