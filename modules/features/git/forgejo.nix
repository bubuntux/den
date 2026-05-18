{ self, ... }:
{
  flake.nixosModules.forgejo =
    { lib, ... }:
    let
      port = 3000;
      sshPort = 2222;
    in
    {
      # Forgejo's log format is gitea-compatible. labels.type = "gitea"
      # routes journald entries to LePresidente/gitea-logs (which filters
      # by program == 'gitea').
      services.crowdsec.hub.collections = [ "LePresidente/gitea" ];
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=forgejo.service" ];
          labels.type = "gitea";
        }
      ];

      services.reverse-proxy.routes.forgejo = {
        inherit port;
        aliases = [ "git" ];
        public = true;
        # Rate-limit login (5/IP/min defaults). Registration is disabled
        # upstream so /user/sign_up doesn't need its own limit.
        rateLimit.paths = [
          "/user/login"
          "/user/login/*"
        ];
        # Default Caddy transport timeout (30s) chokes large git pushes /
        # LFS transfers; 10 minutes is the typical recommendation.
        proxyConfig = ''
          transport http {
            read_timeout 600s
            write_timeout 600s
          }
        '';
      };

      services.forgejo = {
        enable = true;
        lfs.enable = true;

        database.type = "sqlite3";

        dump = {
          enable = true;
          backupDir = "/mnt/data/forgejo-dumps";
          type = "tar.zst";
          interval = "04:31";
          age = "30d";
        };

        settings = {
          server = {
            DOMAIN = "appa.local";
            ROOT_URL = "http://appa.local:${toString port}/";
            HTTP_ADDR = "0.0.0.0";
            HTTP_PORT = port;
            SSH_PORT = sshPort;
            START_SSH_SERVER = true;
            DISABLE_SSH = false;
          };
          service.DISABLE_REGISTRATION = true;
          session.COOKIE_SECURE = false;
          log.LEVEL = "Info";
        };
      };

      systemd.tmpfiles.rules = [
        "d /mnt/data/forgejo-dumps 0750 forgejo forgejo - -"
      ];

      networking.firewall.extraInputRules = ''
        ip saddr { ${lib.concatStringsSep ", " self.lib.lan.ipv4} } tcp dport { ${toString port}, ${toString sshPort} } accept
        ip6 saddr { ${lib.concatStringsSep ", " self.lib.lan.ipv6} } tcp dport { ${toString port}, ${toString sshPort} } accept
      '';

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
