{ self, ... }:
{
  flake.nixosModules.profile-base = {
    imports = with self.nixosModules; [
      boot
      fonts
      locale
      networking
      nix
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
