{ self, ... }:
{
  flake.homeModules.power-profile-auto =
    { pkgs, ... }:
    let
      idleInhibitInit = pkgs.writeShellScript "idle-inhibit-init" ''
        for supply in /sys/class/power_supply/*/; do
          if [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ] && [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
            ${pkgs.systemd}/bin/systemctl --user start idle-inhibit-ac.service
            exit 0
          fi
        done
      '';
    in
    {
      systemd.user.services.idle-inhibit-ac = {
        Unit.Description = "Inhibit idle when on AC power";
        Service = {
          ExecStart = "${pkgs.wlinhibit}/bin/wlinhibit";
          Restart = "on-failure";
        };
      };

      # Check AC state on login and start idle inhibitor if on AC
      systemd.user.services.idle-inhibit-init = {
        Unit = {
          Description = "Initialize idle inhibitor based on AC state";
          After = [ "idle-inhibit-ac.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = idleInhibitInit;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

  flake.nixosModules.power-profile-auto =
    { pkgs, ... }:
    let
      powerProfileSwitch = pkgs.writeShellScript "power-profile-switch" ''
        # Check all power supplies for an online AC adapter
        ac_online=0
        for supply in /sys/class/power_supply/*/; do
          if [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ]; then
            if [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
              ac_online=1
              break
            fi
          fi
        done

        if [ "$ac_online" = "1" ]; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
          ${pkgs.brightnessctl}/bin/brightnessctl set 100%
        else
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
          ${pkgs.brightnessctl}/bin/brightnessctl set 50%
        fi

        # Toggle idle inhibitor for all logged-in users
        for user in $(${pkgs.systemd}/bin/loginctl list-users --no-legend | ${pkgs.gawk}/bin/awk '{print $2}'); do
          if [ "$ac_online" = "1" ]; then
            ${pkgs.systemd}/bin/systemctl --machine="$user@.host" --user start idle-inhibit-ac.service 2>/dev/null || true
          else
            ${pkgs.systemd}/bin/systemctl --machine="$user@.host" --user stop idle-inhibit-ac.service 2>/dev/null || true
          fi
        done
      '';
    in
    {
      home-manager.sharedModules = [ self.homeModules.power-profile-auto ];

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
