{ self, ... }:
{
  flake.nixosModules.profile-wife = {
    imports = with self.nixosModules; [
      user-dona
      gnome
    ];
  };
}
