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

    # LAN ranges that can reach the namespaced services through the host.
    # Lives here rather than in vpn-confinement.nix to avoid list-duplication
    # when vpn-confinement is imported via multiple service paths.
    vpnNamespaces.wg.accessibleFrom = [
      "127.0.0.1"
      "192.168.0.0/16"
      "10.0.0.0/8"
    ];
  };
}
