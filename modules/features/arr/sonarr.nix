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

      services.reverse-proxy.routes.sonarr = {
        inherit port;
        aliases = [ "tv" ];
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
