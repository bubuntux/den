{ self, ... }:
{
  flake.modules.nixos.profile-nas =
    { lib, ... }:
    {
      key = "den:nixos.profile-nas";
      imports = with self.modules.nixos; [
        # A NAS is a whole-machine role, so it brings the machine foundation and
        # its operator, the way profile-workstation does. Hosts then add only
        # hardware.
        bundle-host
        user-bbtux

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
        syncthing
        tvheadend
      ];

      services.reverse-proxy.enable = true;

      # Owns /mnt/media so the services can co-write. One-time reconciliation
      # after first switch:
      #   sudo chgrp -R media /mnt/media
      #   sudo find /mnt/media -type d -exec chmod g+rwxs {} +
      #   sudo find /mnt/media -type f -exec chmod g+rw {} +
      # Pinned because the tvheadend container joins it by numeric GID and
      # auto-assigned ones are not stable. 984 matches the on-disk state on
      # appa; moving it means chgrp'ing all of /mnt/media under a freeze.
      users.groups.media.gid = 984;

      # LAN ranges that may reach the namespaced services. accessibleFrom adds a
      # route per entry, so fe80::/10 is filtered out: a global route for
      # link-local via a ULA next-hop can fail the namespace activation.
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
