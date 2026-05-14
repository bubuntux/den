{
  flake.nixosModules.immich =
    {
      config,
      pkgs,
      ...
    }:
    let
      port = 2283;
    in
    {
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
        inherit port;
      };

      # Brute-force detection from Immich's own log stream — auth attempts
      # below the caddy-ratelimit threshold still get caught here.
      services.crowdsec.hub.collections = [ "gauth-fr/immich" ];
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=immich-server.service" ];
          labels.type = "immich";
        }
      ];

      services.reverse-proxy.routes.immich = {
        inherit port;
        aliases = [ "photos" ];
        public = true;
        # Rate-limit the login endpoint (5/IP/min defaults).
        rateLimit.paths = [ "/api/auth/login" ];
        # Default Caddy body limit (10 MB) is too small for photo / 4K-video
        # uploads. Bump to 50 GB; Immich does chunked uploads above that.
        extraConfig = ''
          request_body {
            max_size 50GB
          }
        '';
      };

      services.backup.targets.immich = {
        paths = [ config.services.immich.mediaLocation ];
        # Both are re-derivable from the originals on demand.
        exclude = [
          "${config.services.immich.mediaLocation}/encoded-video"
          "${config.services.immich.mediaLocation}/thumbs"
        ];
        # Crash-consistent pg_dump of the Immich DB. Restic walks the
        # filesystem after this returns, so the dump is part of the snapshot.
        prepareCommand = ''
          ${pkgs.util-linux}/bin/runuser -u postgres -- \
            ${config.services.postgresql.package}/bin/pg_dump -Fc ${config.services.immich.database.name} \
            > $STAGING/immich.dump.tmp
          mv $STAGING/immich.dump.tmp $STAGING/immich.dump
        '';
        cleanupCommand = ''
          rm -f $STAGING/immich.dump
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
