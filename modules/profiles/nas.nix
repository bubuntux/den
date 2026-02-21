{ self, ... }:
{
  flake.nixosModules.profile-nas = _: {
    imports = with self.nixosModules; [
      jellyfin
    ];
  };
}
