_: {
  flake.nixosModules.bluetooth =
    { lib, pkgs, ... }:
    {
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
    };
}
