{ self, ... }:
{
  flake.nixosModules.profile-wife = _: {
    imports = with self.nixosModules; [
      user-shari
      gnome
      firefox
    ];
  };
}
