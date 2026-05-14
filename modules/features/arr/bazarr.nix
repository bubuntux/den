{
  flake.nixosModules.bazarr =
    {
      config,
      pkgs,
      ...
    }:
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

      services.backup.targets.bazarr = {
        paths = [ "/var/lib/bazarr" ];
        prepareCommand = ''
          ${pkgs.sqlite}/bin/sqlite3 ${config.services.bazarr.dataDir}/db/bazarr.db \
            ".backup $STAGING/bazarr.db"
        '';
        cleanupCommand = ''
          rm -f $STAGING/bazarr.db
        '';
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
