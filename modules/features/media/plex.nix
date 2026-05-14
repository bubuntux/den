{
  flake.nixosModules.plex =
    { config, pkgs, ... }:
    # Upstream services.plex module has no port option; 32400 is the Plex
    # Media Server's hard-coded web port.
    let
      port = 32400;
      pms = "${config.services.plex.dataDir}/Plex Media Server";
      dbDir = "${pms}/Plug-in Support/Databases";
    in
    {
      services.plex = {
        enable = true;
        openFirewall = true;
      };

      # Allowlist for Plex's own infrastructure (Plex Relay, metadata) so
      # legitimate Plex traffic doesn't get flagged. No acquisition needed
      # — this collection only ships a parser that whitelists known IPs.
      services.crowdsec.hub.collections = [ "crowdsecurity/plex" ];

      services.reverse-proxy.routes.plex = {
        inherit port;
        aliases = [ "px" ];
        public = true;
        # Disable response buffering so streaming starts responding to the
        # client immediately (matters for video seek / first-frame latency).
        proxyConfig = ''
          flush_interval -1
        '';
      };

      services.backup.targets.plex = {
        paths = [ config.services.plex.dataDir ];
        # Cache + logs are regeneratable and churn constantly. Metadata is
        # kept — re-fetching it triggers full library re-scans which can
        # take days on a large library. The live SQLite DBs are excluded
        # so restore uses the consistent .backup copies in $STAGING instead
        # of a possibly mid-write file snapshot.
        exclude = [
          "${pms}/Cache"
          "${pms}/Logs"
          "${pms}/Crash Reports"
          "${dbDir}/com.plexapp.plugins.library.db"
          "${dbDir}/com.plexapp.plugins.library.db-shm"
          "${dbDir}/com.plexapp.plugins.library.db-wal"
          "${dbDir}/com.plexapp.plugins.library.blobs.db"
          "${dbDir}/com.plexapp.plugins.library.blobs.db-shm"
          "${dbDir}/com.plexapp.plugins.library.blobs.db-wal"
        ];
        prepareCommand = ''
          ${pkgs.sqlite}/bin/sqlite3 "${dbDir}/com.plexapp.plugins.library.db" \
            ".backup '$STAGING/library.db'"
          ${pkgs.sqlite}/bin/sqlite3 "${dbDir}/com.plexapp.plugins.library.blobs.db" \
            ".backup '$STAGING/library.blobs.db'"
        '';
        cleanupCommand = ''
          rm -f "$STAGING/library.db" "$STAGING/library.blobs.db"
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
