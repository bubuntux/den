{ self, ... }:
{
  # Home Manager module for bluetooth
  flake.homeModules.bluetooth = {
    services.blueman-applet.enable = true;
  };

  # NixOS module for bluetooth
  flake.nixosModules.bluetooth =
    { lib, ... }:
    {
      services.blueman.enable = true;
      hardware.bluetooth = {
        enable = lib.mkDefault true;
        powerOnBoot = lib.mkDefault true;
      };

      # Add home-manager bluetooth module to shared modules
      home-manager.sharedModules = [ self.homeModules.bluetooth ];
    };
}
