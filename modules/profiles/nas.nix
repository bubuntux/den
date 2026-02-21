{ self, ... }:
{
  flake.nixosModules.profile-nas = _: {
    imports = with self.nixosModules; [
      bazarr
      jellyfin
      radarr
      sonarr
    ];
  };
}
