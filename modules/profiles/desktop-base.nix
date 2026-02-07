{ self, ... }:
{
  flake.nixosModules.profile-desktop-base = {
    imports = with self.nixosModules; [
      profile-base
    ];
  };
}
