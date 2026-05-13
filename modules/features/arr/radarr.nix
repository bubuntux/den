{
  flake.nixosModules.radarr =
    _:
    let
      port = 7878;
    in
    {
      services.radarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      services.reverse-proxy.routes.radarr = {
        inherit port;
        aliases = [ "movies" ];
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
