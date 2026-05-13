{
  flake.nixosModules.bazarr =
    _:
    let
      port = 6767;
    in
    {
      services.bazarr = {
        enable = true;
        openFirewall = true;
        listenPort = port;
      };

      services.reverse-proxy.routes.bazarr = {
        inherit port;
        aliases = [ "subs" ];
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
