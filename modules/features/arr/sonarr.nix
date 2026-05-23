{
  flake.nixosModules.sonarr =
    { config, lib, ... }:
    let
      port = 8989;
    in
    {
      services.sonarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      users.users.sonarr.extraGroups = [ "media" ];

      # 0002 so files/dirs sonarr creates under /mnt/media keep group
      # write -- needed for radarr/bazarr/qbittorrent (all in the media
      # group) to manage the same trees.
      systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";

      # Library lives on /mnt/media; without this the unit can start
      # before the disk mounts and create paths on the root fs.
      systemd.services.sonarr.unitConfig.RequiresMountsFor = [ "/mnt/media" ];

      # Resource caps (percent-of-RAM scales with hardware upgrades).
      # Sonarr's .NET runtime has been observed peaking at 1.28 GB during
      # library-wide refresh scans on appa, the largest non-immich consumer
      # on the host. Cap above peak so scans don't OOM, below 1/5 of RAM so
      # a runaway scan can't drown the box. CPUWeight=75 puts it below
      # streamers (150) but above bulk-bg (50).
      systemd.services.sonarr.serviceConfig = {
        MemoryHigh = "12%";
        MemoryMax = "18%";
        CPUWeight = 75;
        IOWeight = 75;
      };

      services.reverse-proxy.routes.sonarr = {
        inherit port;
        aliases = [
          "tv"
          "shows"
        ];
      };

      # .wg alias so prowlarr (inside the wg netns) can dial us by name —
      # /etc/hosts is shared with the namespace because systemd's
      # NetworkNamespacePath only switches the net ns, not the mount ns.
      # Implicit dep: a host using this module must also import
      # vpn-confinement (true on appa via profile-nas).
      networking.hosts.${config.vpnNamespaces.wg.bridgeAddress} = [ "sonarr.wg" ];

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
