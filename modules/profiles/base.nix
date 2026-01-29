{ self, ... }:
{
  flake.nixosModules.base = {
    imports = [
      self.nixosModules.boot
      self.nixosModules.nix
    ];
  };
}
