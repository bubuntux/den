{ self, ... }:
{
  flake.nixosModules.profile-nas =
    { lib, ... }:
    {
      imports = with self.nixosModules; [
        bazarr
        cloudflare-ddns
        crowdsec
        crowdsec-bouncers
        # forgejo
        home-assistant-proxy
        immich
        jellyfin
        openssh
        plex
        podman
        prowlarr
        qbittorrent
        radarr
        restic
        reverse-proxy
        sonarr
        tvheadend
      ];

      services.reverse-proxy.enable = true;

      # Shared group joined by each media service (radarr, sonarr, ...)
      # via its own feature file. Owns the /mnt/media tree so the services
      # can co-write without one service's umask locking another out.
      #
      # First-time perms reconciliation on the host (run once after switch):
      #   sudo chgrp -R media /mnt/media
      #   sudo find /mnt/media -type d -exec chmod g+rwxs {} +
      #   sudo find /mnt/media -type f -exec chmod g+rw {} +
      # The setgid bit on dirs makes new files inherit the media group from
      # then on.
      # Pinned GID so the tvheadend OCI container can request supplementary
      # group access via `--group-add=<gid>` deterministically across rebuilds.
      # NixOS auto-assigned GIDs aren't stable across host rebuilds, which
      # would silently break the container's write access to /mnt/media after
      # any user/group reshuffle. 984 is where NixOS originally landed it on
      # appa, kept here so the pin matches the on-disk state and doesn't
      # collide with dhcpcd's GID 990 — moving it would require chgrp'ing
      # the full /mnt/media tree under a service freeze.
      users.groups.media.gid = 984;

      # LAN ranges that can reach the namespaced services through the host.
      # Lives here rather than in vpn-confinement.nix to avoid list-duplication
      # when vpn-confinement is imported via multiple service paths.
      #
      # vpn-confinement implements accessibleFrom by running
      # `ip -n <ns> route add <cidr> via <bridge>` for each entry. fe80::/10 is
      # filtered out because installing a global route for link-local via a
      # ULA next-hop is semantically wrong and the kernel may reject it,
      # failing the namespace's activation. The remaining ULA prefix
      # (fd00::/8) plus loopback (127.0.0.1 / ::1) cover return-traffic
      # routing for everything we want to reach the namespace.
      #
      # Same list applies to wg-tvh — the streamlink SOCKS proxy receives
      # connections from the tvheadend container's post-NAT source IP (the
      # host's LAN address), so the LAN ranges authorize that return path.
      vpnNamespaces =
        let
          lanAccess =
            self.lib.lan.ipv4
            ++ lib.filter (cidr: cidr != "fe80::/10") self.lib.lan.ipv6
            ++ [
              "127.0.0.1"
              "::1"
            ];
        in
        {
          wg.accessibleFrom = lanAccess;
          wg-tvh.accessibleFrom = lanAccess;
        };
    };
}
