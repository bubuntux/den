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
