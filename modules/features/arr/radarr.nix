{
  flake.nixosModules.radarr =
    { config, lib, ... }:
    let
      port = 7878;
    in
    {
      services.radarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      users.users.radarr.extraGroups = [ "media" ];

      # 0002 so files/dirs radarr creates under /mnt/media keep group
      # write -- needed for sonarr/bazarr/qbittorrent (all in the media
      # group) to manage the same trees.
      systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";

      # Library lives on /mnt/media; without this the unit can start
      # before the disk mounts and create paths on the root fs.
      systemd.services.radarr.unitConfig.RequiresMountsFor = [ "/mnt/media" ];

      # Resource caps (percent-of-RAM scales with hardware upgrades).
      # Symmetric with Sonarr's .NET runtime — observed peaks of ~560 MB
      # with a smaller library than Sonarr's. CPUWeight=75 puts it below
      # streamers (150) but above bulk-bg (50).
      systemd.services.radarr.serviceConfig = {
        MemoryHigh = "8%";
        MemoryMax = "15%";
        CPUWeight = 75;
        IOWeight = 75;
      };

      services.reverse-proxy.routes.radarr = {
        inherit port;
        aliases = [ "movies" ];
      };

      # .wg alias so prowlarr (inside the wg netns) can dial us by name —
      # see sonarr.nix for the full rationale.
      networking.hosts.${config.vpnNamespaces.wg.bridgeAddress} = [ "radarr.wg" ];

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
