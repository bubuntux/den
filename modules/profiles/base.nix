{ self, ... }:
{
  flake.nixosModules.base = {
    imports = [
      self.nixosModules.boot
      self.nixosModules.locale
      self.nixosModules.networking
      self.nixosModules.nix
    ];
  };
}
