_: {
  flake.modules.nixos.bluetooth =
    { lib, pkgs, ... }:
    {
      key = "den:nixos.bluetooth";
      services.blueman.enable = true;
      hardware.bluetooth = {
        enable = lib.mkDefault true;
        powerOnBoot = lib.mkDefault true;
      };

      # services.blueman.enable ships the upstream blueman user unit
      # (via systemd.packages) and adds a drop-in with its own ExecStart=.
      # systemd 260+ refuses the resulting unit ("Service has more than one
      # ExecStart="), so reset the inherited ExecStart= before setting it.
      # Start it with graphical-session.target, wait for the StatusNotifierWatcher
      # D-Bus interface so blueman-tray registers an SNI item instead of
      # falling back to an XEmbed icon, and mask the autostart generator unit.
      systemd.user.services.blueman-applet = {
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = lib.mkForce [
            ""
            "${pkgs.blueman}/bin/blueman-applet"
          ];
          ExecStartPre = pkgs.writeShellScript "wait-for-sni" ''
            for _ in $(seq 1 30); do
              ${pkgs.systemd}/bin/busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && exit 0
              sleep 0.1
            done
            exit 0
          '';
        };
      };

      systemd.user.services."app-blueman@autostart".enable = false;
    };
}
