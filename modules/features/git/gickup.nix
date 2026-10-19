{ self, ... }:
{
  flake.modules.nixos.gickup =
    { config, pkgs, ... }:
    let
      backupDir = "/mnt/data/gickup";
      secrets = config.sops.secrets;

      settings = {
        source.github = [
          {
            token_file = secrets.gickup_github_token.path;
            user = "bubuntux";
            # Matched against the owner, so collaborator and org repos stay out.
            includeorgs = [ "bubuntux" ];
            filter.excludeforks = true;
          }
        ];
        destination = {
          gitlab = [
            {
              token_file = secrets.gickup_gitlab_token.path;
              user = "julio-guti";
              mirror.enabled = true;
            }
          ];
          # Codeberg is Forgejo, which gickup drives through its gitea API.
          gitea = [
            {
              url = "https://codeberg.org";
              token_file = secrets.gickup_codeberg_token.path;
              user = "botanical186";
              mirror.enabled = true;
            }
          ];
          local = [
            {
              path = backupDir;
              structured = true;
              bare = true;
              mirror = true;
            }
          ];
        };
      };
      configFile = (pkgs.formats.yaml { }).generate "gickup.yml" settings;
    in
    {
      key = "den:nixos.gickup";
      imports = [ self.modules.nixos.sops ];

      sops.secrets = {
        gickup_github_token = {
          sopsFile = "${self}/secrets/appa.yaml";
          owner = "gickup";
        };
        gickup_gitlab_token = {
          sopsFile = "${self}/secrets/appa.yaml";
          owner = "gickup";
        };
        gickup_codeberg_token = {
          sopsFile = "${self}/secrets/appa.yaml";
          owner = "gickup";
        };
      };

      users.users.gickup = {
        isSystemUser = true;
        group = "gickup";
      };
      users.groups.gickup = { };

      systemd.tmpfiles.rules = [
        "d ${backupDir} 0750 gickup gickup - -"
      ];

      systemd.services.gickup = {
        description = "Mirror GitHub repositories to GitLab, Codeberg and ${backupDir}";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [ backupDir ];
        serviceConfig = {
          Type = "oneshot";
          User = "gickup";
          Group = "gickup";
          ExecStart = "${pkgs.gickup}/bin/gickup ${configFile}";

          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ backupDir ];
          NoNewPrivileges = true;

          CPUWeight = 30;
          CPUQuota = "200%";
          IOWeight = 30;
          MemoryHigh = "15%";
          MemoryMax = "20%";
        };
      };

      # Ahead of restic's 06:30 run, so each night's snapshot holds that day's mirrors.
      systemd.timers.gickup = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "05:15";
          Persistent = true;
          RandomizedDelaySec = "15min";
        };
      };
    };
}
