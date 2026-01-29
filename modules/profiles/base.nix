{ self, ... }:
{
  flake.nixosModules.base = {
    imports = [
      self.nixosModules.boot
      self.nixosModules.nix
      self.nixosModules.locale
    ];
  };
}
