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

      # services.blueman.enable both ships the upstream blueman user unit
      # (via systemd.packages) and adds a drop-in with its own ExecStart=.
      # systemd 260+ refuses the resulting unit
      # ("Service has more than one ExecStart="). Reset the inherited
      # ExecStart= before re-setting it so the override lands cleanly.
      systemd.user.services.blueman-applet.serviceConfig.ExecStart = lib.mkForce [
        ""
        "${pkgs.blueman}/bin/blueman-applet"
      ];

      # Wait for the StatusNotifierWatcher D-Bus interface so blueman-tray
      # registers an SNI item rather than falling back to an XEmbed status icon.
      systemd.user.services."app-blueman@autostart".serviceConfig.ExecStartPre =
        pkgs.writeShellScript "wait-for-sni" ''
          for _ in $(seq 1 30); do
            ${pkgs.systemd}/bin/busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && exit 0
            sleep 0.1
          done
          exit 0
        '';
    };
}
