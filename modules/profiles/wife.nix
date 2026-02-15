{ self, ... }:
{
  flake.nixosModules.profile-wife = {
    imports = with self.nixosModules; [
      user-shari
      gnome
      firefox
    ];
  };
}
