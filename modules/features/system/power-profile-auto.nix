{ self, ... }:
{
  flake.nixosModules.power-profile-auto =
    { pkgs, ... }:
    let
      powerProfileSwitch = pkgs.writeShellScript "power-profile-switch" ''
        # Check all power supplies for an online AC adapter
        for supply in /sys/class/power_supply/*/; do
          if [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ]; then
            if [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
              ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
              exit 0
            fi
          fi
        done
        # No AC adapter online — switch to power-saver
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
      '';
    in
    {
      # Run at boot to set the initial profile and on every AC state change
      systemd.services.power-profile-auto = {
        description = "Switch power profile based on AC adapter state";
        after = [ "power-profiles-daemon.service" ];
        requires = [ "power-profiles-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = powerProfileSwitch;
        };
        wantedBy = [ "multi-user.target" ];
      };

      # Trigger the service whenever the AC adapter is plugged/unplugged
      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}="power-profile-auto.service"
      '';
    };
}
