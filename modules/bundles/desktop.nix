{ self, ... }:
{
  flake.nixosModules.bundle-desktop =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        bundle-base
      ];

      # Enable networking
      networking.networkmanager.enable = true;

      # Disable NixOS Manual
      documentation.nixos.enable = false;

      environment.systemPackages = with pkgs; [
        kdePackages.okular # Powerful PDF viewer
        qalculate-gtk # Versatile calculator
      ];
    };
}
