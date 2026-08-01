_:
let
  # Succeeds when an AC adapter is plugged in. Detection is by power-supply
  # *type*, never by device name: the adapter enumerates differently per machine
  # (ACAD on katara, AC on others), so globbing and matching "Mains" is what
  # keeps this working on any laptop.
  acOnline =
    pkgs:
    pkgs.writeShellScript "ac-online" ''
      for supply in /sys/class/power_supply/*/; do
        if [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ] && [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
          exit 0
        fi
      done
      exit 1
    '';
in
{
  flake.modules = {
    homeManager.power-profile-auto =
      { pkgs, config, ... }:
      let
        idleInhibitInit = pkgs.writeShellScript "idle-inhibit-init" ''
          # Stop swayidle if on AC power
          if ${acOnline pkgs}; then
            ${pkgs.systemd}/bin/systemctl --user stop swayidle.service
          fi
        '';
      in
      {
        key = "den:homeManager.power-profile-auto";
        # Stops swayidle at login when on AC. Ordered against the session target
        # explicitly (a WantedBy with no ordering creates an implicit reverse edge
        # and an ordering cycle), and deliberately no Requires=swayidle: that
        # would propagate the stop back and SIGTERM this script mid-run.
        systemd.user.services.idle-inhibit-init = {
          Unit = {
            Description = "Initialize idle inhibitor based on AC state";
            After = [
              config.wayland.systemd.target
              "swayidle.service"
            ];
            PartOf = [ config.wayland.systemd.target ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = idleInhibitInit;
          };
          Install.WantedBy = [ config.wayland.systemd.target ];
        };
      };

    nixos.power-profile-auto =
      { pkgs, ... }:
      let
        powerProfileSwitch = pkgs.writeShellScript "power-profile-switch" ''
          if ${acOnline pkgs}; then
            ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
            ${pkgs.brightnessctl}/bin/brightnessctl set 100%
            swayidle_action=stop
          else
            ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
            ${pkgs.brightnessctl}/bin/brightnessctl set 50%
            swayidle_action=start
          fi

          # Toggle swayidle for all logged-in users (stop on AC, start on battery)
          for user in $(${pkgs.systemd}/bin/loginctl list-users --no-legend | ${pkgs.gawk}/bin/awk '{print $2}'); do
            ${pkgs.systemd}/bin/systemctl --machine="$user@.host" --user "$swayidle_action" swayidle.service 2>/dev/null || true
          done
        '';
      in
      {
        key = "den:nixos.power-profile-auto";

        # No sharedModules for the home half: session/wayland.nix imports it, so
        # only bare-session users get it. The loop below cannot be scoped that
        # way -- a system service cannot know which session each user runs, so it
        # asks all of them and swallows the failures.

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
  };
}
