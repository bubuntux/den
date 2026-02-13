{ self, ... }:
{
  flake.nixosModules.bundle-base = {
    imports = with self.nixosModules; [
      boot
      fonts
      home-manager
      locale
      networking
      nix
    ];

    home-manager.sharedModules = with self.homeModules; [
      bundle-base
    ];
  };

  flake.homeModules.bundle-base = {
    imports = with self.homeModules; [
      fonts
      helix
      neovim
    ];
  };

}
