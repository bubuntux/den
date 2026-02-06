{ self, ... }:
{
  flake.nixosModules.profile-wife = {
    imports = with self.nixosModules; [
      home-dona
      gnome
    ];
  };
}
