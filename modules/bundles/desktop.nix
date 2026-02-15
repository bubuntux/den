{ self, ... }:
{
  # Home Manager module for desktop environments
  flake.homeModules.bundle-desktop =
    { pkgs, ... }:
    {
      imports = [ self.homeModules.mpv ];

      targets.genericLinux.enable = true;
      services.network-manager-applet.enable = true;

      # XDG configuration
      xdg = {
        enable = true;
        mimeApps.enable = true;
      };

      # Desktop packages
      home.packages = with pkgs; [
        kdePackages.okular # PDF viewer
        qalculate-gtk # Calculator
        loupe # Image viewer
        pwvucontrol # PipeWire volume control
      ];
    };

  # NixOS module for desktop environments
  flake.nixosModules.bundle-desktop = {
    imports = with self.nixosModules; [
      bundle-base
      theme
    ];

    # Enable networking
    networking.networkmanager.enable = true;

    # Disable NixOS Manual
    documentation.nixos.enable = false;

    # Add home-manager bundle-desktop module to shared modules
    home-manager.sharedModules = [ self.homeModules.bundle-desktop ];
  };
}
