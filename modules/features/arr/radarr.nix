{
  flake.nixosModules.radarr =
    { config, ... }:
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
