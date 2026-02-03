{ self, ... }:
{
  flake.nixosModules.base = {
    imports = [
      self.nixosModules.boot
      self.nixosModules.fonts
      self.nixosModules.locale
      self.nixosModules.networking
      self.nixosModules.nix
    ];
  };

  flake.homeModules.base = {
    imports = [
      self.homeModules.fonts
      self.homeModules.helix
      self.homeModules.neovim
    ];
  };

}
