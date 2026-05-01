_: {
  # NixOS module for bluetooth.
  # services.blueman.enable already provides a fully-wired user unit for
  # blueman-applet (WantedBy=graphical-session.target), so no Home Manager
  # side is needed — adding `services.blueman-applet.enable` there caused a
  # duplicate ExecStart= which systemd 260+ refuses to load.
  flake.nixosModules.bluetooth =
    { lib, ... }:
    {
      services.blueman.enable = true;
      hardware.bluetooth = {
        enable = lib.mkDefault true;
        powerOnBoot = lib.mkDefault true;
      };
    };
}
