{ self, ... }:
{
  flake.nixosModules.profile-laptop = {
    imports = with self.nixosModules; [
      profile-base
      audio
      printing
    ];
  };
}
