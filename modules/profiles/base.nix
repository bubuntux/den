{ self, ... }:
{
  flake.nixosModules.base = {
    imports = with self.nixosModules; [
      boot
      fonts
      locale
      networking
      nix
    ];
  };

  flake.homeModules.base = {
    imports = with self.homeModules; [
      fonts
      helix
      neovim
    ];
  };

}
