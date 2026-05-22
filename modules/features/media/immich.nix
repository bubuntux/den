{
  flake.nixosModules.immich =
    { lib, ... }:
    let
      port = 2283;
      mediaLocation = "/mnt/data/immich";
      # Immich verifies a `.immich` sentinel in each of these subdirs on
      # startup; pre-seed them so the integrity check passes on a custom
      # mediaLocation (with the default /var/lib/immich the upstream
      # bootstrap creates them, but with mountChecks already enabled in the
      # DB the verify runs before that path).
      mountFolders = [
        "encoded-video"
        "thumbs"
        "upload"
        "backups"
        "library"
        "profile"
      ];
    in
    {
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
        inherit port mediaLocation;
      };

      # Cap the immich slice so a runaway ML/import job can't OOM-lock the
      # host. Both immich-server and immich-machine-learning already run in
      # Slice=system-immich.slice; declaring the slice here adds the limits.
      # Reason: 2026-05-22 kernel page-fault BUG during bulk photo ingest on
      # an 8 GB-RAM host (OCR + face-detect + Redis BGSAVE concurrency).
      systemd.slices.system-immich.sliceConfig = {
        MemoryHigh = "3G";
        MemoryMax = "4G";
        MemorySwapMax = "2G";
      };

      systemd.tmpfiles.rules = [
        "d ${mediaLocation} 0750 immich immich - -"
      ]
      ++ lib.concatMap (folder: [
        "d ${mediaLocation}/${folder} 0700 immich immich - -"
        "f ${mediaLocation}/${folder}/.immich 0600 immich immich - -"
      ]) mountFolders;

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

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
