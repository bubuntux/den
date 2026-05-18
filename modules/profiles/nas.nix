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
        immich
        jellyfin
        openssh
        plex
        prowlarr
        qbittorrent
        radarr
        reverse-proxy
        sonarr
      ];

      services.reverse-proxy.enable = true;

      # LAN ranges that can reach the namespaced services through the host.
      # Lives here rather than in vpn-confinement.nix to avoid list-duplication
      # when vpn-confinement is imported via multiple service paths.
      #
      # vpn-confinement implements accessibleFrom by running
      # `ip -n wg route add <cidr> via <bridge>` for each entry. fe80::/10 is
      # filtered out because installing a global route for link-local via a
      # ULA next-hop is semantically wrong and the kernel may reject it,
      # failing wg.service activation. The remaining ULA prefix (fd00::/8)
      # plus loopback (127.0.0.1 / ::1) cover return-traffic routing for
      # everything we want to reach the namespace.
      vpnNamespaces.wg.accessibleFrom =
        self.lib.lan.ipv4
        ++ lib.filter (cidr: cidr != "fe80::/10") self.lib.lan.ipv6
        ++ [
          "127.0.0.1"
          "::1"
        ];
    };
}
