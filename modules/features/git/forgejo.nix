{
  flake.nixosModules.forgejo = _: {
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
          ROOT_URL = "http://appa.local:3000/";
          HTTP_ADDR = "0.0.0.0";
          HTTP_PORT = 3000;
          SSH_PORT = 2222;
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
      ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } tcp dport { 3000, 2222 } accept
    '';
  };
}
