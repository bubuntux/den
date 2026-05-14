{
  flake.nixosModules.radarr =
    {
      config,
      pkgs,
      ...
    }:
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

      services.backup.targets.radarr = {
        paths = [ "/var/lib/radarr" ];
        prepareCommand = ''
          ${pkgs.sqlite}/bin/sqlite3 ${config.services.radarr.dataDir}/radarr.db \
            ".backup $STAGING/radarr.db"
        '';
        cleanupCommand = ''
          rm -f $STAGING/radarr.db
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
