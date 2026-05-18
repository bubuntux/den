{
  flake.nixosModules.sonarr =
    _:
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

      services.reverse-proxy.routes.sonarr = {
        inherit port;
        aliases = [
          "tv"
          "shows"
        ];
      };

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
