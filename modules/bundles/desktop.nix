{ self, ... }:
{
  # Home Manager module for desktop environments
  flake.homeModules.bundle-desktop = {
    imports = [ self.homeModules.mpv ];
    targets.genericLinux.enable = true;
    services.network-manager-applet.enable = true;
  };

  # NixOS module for desktop environments
  flake.nixosModules.bundle-desktop =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        bundle-base
        theme
      ];

      # Enable networking
      networking.networkmanager.enable = true;

      # Disable NixOS Manual
      documentation.nixos.enable = false;

      environment.systemPackages = with pkgs; [
        kdePackages.okular # Powerful PDF viewer
        qalculate-gtk # Versatile calculator
      ];

      # Add home-manager bundle-desktop module to shared modules
      home-manager.sharedModules = [ self.homeModules.bundle-desktop ];
    };
}
