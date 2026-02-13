{ self, ... }:
{
  flake.nixosModules.bundle-desktop = {
    imports = with self.nixosModules; [
      bundle-base
    ];

    # Enable networking
    networking.networkmanager.enable = true;
  };
}
