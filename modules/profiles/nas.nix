{ self, ... }:
{
  flake.nixosModules.profile-nas = _: {
    imports = with self.nixosModules; [
      bazarr
      cloudflare-ddns
      crowdsec
      crowdsec-bouncers
      # forgejo
      immich
      jellyfin
      openssh
      plex
      prowlarr
      qbittorrent
      radarr
      restic
      reverse-proxy
      sonarr
    ];

    services.reverse-proxy.enable = true;

    services.backup = {
      enable = true;
      offsite.enable = true;
      # Catch-all for files living on /mnt/data that aren't owned by a
      # specific service (forgejo declares its own subdir; restic dedups
      # any overlap at the chunk level).
      targets.user-data.paths = [ "/mnt/data" ];
    };

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
