{ self, ... }:
{
  flake.nixosModules.profile-wife = {
    imports = with self.nixosModules; [
      profile-laptop
      gnome
    ];
  };
}
