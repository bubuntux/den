{
  flake.nixosModules.sonarr =
    {
      config,
      pkgs,
      ...
    }:
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

      services.backup.targets.sonarr = {
        paths = [ "/var/lib/sonarr" ];
        # Atomic snapshot of the live SQLite DB — the file inside dataDir
        # may be mid-write at restic-walk time, but the .backup copy is
        # always consistent.
        prepareCommand = ''
          ${pkgs.sqlite}/bin/sqlite3 ${config.services.sonarr.dataDir}/sonarr.db \
            ".backup $STAGING/sonarr.db"
        '';
        cleanupCommand = ''
          rm -f $STAGING/sonarr.db
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
