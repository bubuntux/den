{ self, ... }:
{
  flake.nixosModules.profile-laptop = {
    imports = with self.nixosModules; [
      audio
      bluetooth
      printing
      bundle-base
    ];
  };
}
