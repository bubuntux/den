{ self, ... }:
{
  flake.nixosModules.profile-nas = _: {
    imports = with self.nixosModules; [
      bazarr
      cloudflare-ddns
      forgejo
      immich
      jellyfin
      openssh
      plex
      prowlarr
      qbittorrent
      radarr
      sonarr
    ];
  };
}
