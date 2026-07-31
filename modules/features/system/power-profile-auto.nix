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
        # Stop swayidle on login when on AC. Imported by session/wayland.nix
        # alongside swayidle rather than pushed at every user; see the note on
        # the nixos half below.
        #
        # Bound to wayland.systemd.target, the same unit swayidle itself follows
        # -- session/wayland.nix points it at den-session.target, so this runs
        # under the sessions that have a swayidle to inhibit and not in GNOME,
        # which runs its own idle policy. (Imported without that module it falls
        # back to Home Manager's default of graphical-session.target.)
        #
        # Ordered against that target explicitly, like every other unit in the
        # session. That is load-bearing: a unit that is WantedBy a target but
        # declares no ordering against it gets an implicit "target After= unit"
        # edge, which turned the After=swayidle.service below into an ordering
        # cycle and had systemd drop this job at every login.
        #
        # Deliberately no Requires=swayidle.service either: this unit's whole job
        # is to stop swayidle, and Requires= propagates that stop straight back,
        # SIGTERMing the script mid-run. After= alone is enough to order the two,
        # since the target already pulls swayidle in.
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

        # Deliberately no `home-manager.sharedModules` for the module above: its
        # unit exists to stop swayidle, so pushing it at every user put an
        # idle-inhibit-init on GNOME users too, where it can only fail. The bare
        # sessions import it instead, which is what scopes it per user. GNOME
        # needs none of it -- gnome-settings-daemon runs its own idle and power
        # policy, and this file's system half already sets the profile.
        #
        # The loop below is the one part that cannot be scoped that way: a system
        # service cannot know which session each logged-in user is running, so it
        # asks every one of them and swallows the failure for those without
        # swayidle.

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
