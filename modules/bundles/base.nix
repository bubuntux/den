{ self, ... }:
{
  flake.nixosModules.profile-base = {
    imports = with self.nixosModules; [
      boot
      fonts
      home-manager
      locale
      networking
      nix
    ];

    home-manager.sharedModules = with self.homeModules; [
      profile-base
    ];
  };

  flake.homeModules.profile-base = {
    imports = with self.homeModules; [
      fonts
      helix
      neovim
    ];
  };

}
