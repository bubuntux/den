{
  flake.nixosModules.jellyfin =
    { config, pkgs, ... }:
    # Upstream services.jellyfin module has no port option; these are the
    # hard-coded HTTP/HTTPS ports baked into the Jellyfin binary.
    let
      port = 8096;
      httpsPort = 8920;
      dbDir = "${config.services.jellyfin.dataDir}/data";
    in
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      # Catches actual auth failures from Jellyfin's own log stream — slow
      # brute force that stays below caddy-ratelimit wouldn't otherwise
      # trigger anything.
      services.crowdsec.hub.collections = [ "LePresidente/jellyfin" ];
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=jellyfin.service" ];
          labels.type = "jellyfin";
        }
      ];

      services.reverse-proxy.routes.jellyfin = {
        inherit port;
        aliases = [
          "jf"
          "media"
        ];
        public = true;
        # Rate-limit the login endpoint (5/IP/min defaults). Synchronous
        # check, independent of CrowdSec's log-based scenarios.
        rateLimit.paths = [ "/Users/AuthenticateByName" ];
        # Disable response buffering so streaming starts responding to the
        # client immediately (matters for video seek / first-frame latency).
        proxyConfig = ''
          flush_interval -1
        '';
      };

      services.backup.targets.jellyfin = {
        paths = [ config.services.jellyfin.dataDir ];
        # Cache/transcodes/log regenerate on first scan. Live SQLite DBs
        # are excluded — restore uses the consistent .backup copies in
        # $STAGING.
        exclude = [
          "${config.services.jellyfin.dataDir}/transcodes"
          "${config.services.jellyfin.dataDir}/cache"
          "${config.services.jellyfin.dataDir}/log"
          "${dbDir}/jellyfin.db"
          "${dbDir}/jellyfin.db-shm"
          "${dbDir}/jellyfin.db-wal"
          "${dbDir}/library.db"
          "${dbDir}/library.db-shm"
          "${dbDir}/library.db-wal"
        ];
        prepareCommand = ''
          for db in jellyfin.db library.db; do
            src="${dbDir}/$db"
            [ -f "$src" ] || continue
            ${pkgs.sqlite}/bin/sqlite3 "$src" ".backup '$STAGING/$db'"
          done
        '';
        cleanupCommand = ''
          rm -f "$STAGING"/*.db
        '';
      };

      virtualisation.vmVariant.virtualisation = {
        # Jellyfin 10.10+ refuses to start with <2 GiB free at its data dir.
        # In production the data lives on /mnt/data; in the VM it falls back to /.
        diskSize = 4096;

        forwardPorts = [
          {
            from = "host";
            host.port = port;
            guest.port = port;
          }
          {
            from = "host";
            host.port = httpsPort;
            guest.port = httpsPort;
          }
        ];
      };
    };
}
