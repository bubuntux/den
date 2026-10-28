_: {
  flake.modules.nixos.power-profile-auto =
    { pkgs, ... }:
    let
      # Succeeds when an AC adapter is plugged in. Detection is by power-supply
      # *type*, never by device name: the adapter enumerates differently per
      # machine (ACAD on katara, AC on others), so globbing and matching "Mains"
      # is what keeps this working on any laptop.
      acOnline = pkgs.writeShellScript "ac-online" ''
        for supply in /sys/class/power_supply/*/; do
          if [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ] && [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
            exit 0
          fi
        done
        exit 1
      '';

      powerProfileSwitch = pkgs.writeShellScript "power-profile-switch" ''
        if ${acOnline}; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
          ${pkgs.brightnessctl}/bin/brightnessctl set 100%
        else
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
          ${pkgs.brightnessctl}/bin/brightnessctl set 50%
        fi
      '';
    in
    {
      key = "den:nixos.power-profile-auto";

      # Run at boot to set the initial profile and on every AC state change
      systemd.services.power-profile-auto = {
        description = "Switch power profile based on AC adapter state";
        after = [ "power-profiles-daemon.service" ];
        wants = [ "power-profiles-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = powerProfileSwitch;
        };
        wantedBy = [ "graphical.target" ];
      };

      # Trigger the service whenever the AC adapter is plugged/unplugged
      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}="power-profile-auto.service"
      '';
    };
}
