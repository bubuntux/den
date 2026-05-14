{ self, ... }:
{
  flake.nixosModules.restic =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.backup;
      stagingBase = "/var/backup/restic-staging";

      activeTargets = lib.filterAttrs (_: t: t.enable) cfg.targets;

      withStaging = lib.filterAttrs (_: t: t.prepareCommand != "") activeTargets;

      stagingPaths = map (n: "${stagingBase}/${n}") (lib.attrNames withStaging);

      allPaths = lib.unique (lib.concatMap (t: t.paths) (lib.attrValues activeTargets) ++ stagingPaths);

      allExclude = lib.unique (lib.concatMap (t: t.exclude) (lib.attrValues activeTargets));

      # Each target's snippet runs in its own subshell with $STAGING pointing
      # at the target-private dir. That dir is auto-created (tmpfiles below)
      # and auto-included in restic paths, so dumps land in the snapshot
      # without each service needing to know.
      wrapSnippet =
        name: snippet:
        lib.optionalString (snippet != "") ''
          (
            export STAGING=${stagingBase}/${name}
            ${snippet}
          )
        '';

      mkPrepare =
        let
          body = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (n: t: wrapSnippet n t.prepareCommand) activeTargets
          );
        in
        ''
          set -eu
          ${body}
        '';

      mkCleanup = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (n: t: wrapSnippet n t.cleanupCommand) activeTargets
      );

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];

      commonBackup = {
        passwordFile = config.sops.secrets.restic_password.path;
        initialize = true;
        paths = allPaths;
        exclude = allExclude;
        inherit pruneOpts;
        backupPrepareCommand = mkPrepare;
        backupCleanupCommand = mkCleanup;
      };
    in
    {
      imports = [ self.nixosModules.sops ];

      options.services.backup = {
        enable = lib.mkEnableOption "restic backups aggregating per-service targets";

        offsite.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Mirror the local repo to Google Drive via rclone. Requires an
            rclone remote named `gdrive` configured at
            /var/lib/restic-rclone/rclone.conf on the host. Bootstrap once
            with:
              rclone config --config /var/lib/restic-rclone/rclone.conf
            and create a remote of type "drive" named "gdrive". The token
            stored there is refreshed in place by rclone — keeping it on
            the host (not sops) avoids the read-only-config refresh trap.
          '';
        };

        targets = lib.mkOption {
          default = { };
          description = ''
            Per-service backup contributions. Each service feature module
            declares its own entry here so the restic module stays unaware
            of which backends exist. `prepareCommand` runs with $STAGING
            set to a target-private dir that is automatically backed up;
            use it for pg_dump / sqlite `.backup` / similar.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Include this target in backups.";
                  };
                  paths = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Filesystem paths to back up for ${name}.";
                  };
                  exclude = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Restic exclude patterns for ${name}.";
                  };
                  prepareCommand = lib.mkOption {
                    type = lib.types.lines;
                    default = "";
                    description = ''
                      Shell snippet run before restic. $STAGING is set to a
                      target-private dir (${stagingBase}/${name}) which is
                      auto-created and auto-included in restic paths.
                    '';
                  };
                  cleanupCommand = lib.mkOption {
                    type = lib.types.lines;
                    default = "";
                    description = ''
                      Shell snippet run after restic. $STAGING is the same
                      path as during prepareCommand. Use to clear dumps so
                      they don't sit on disk between runs.
                    '';
                  };
                };
              }
            )
          );
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.restic_password = {
          sopsFile = "${self}/secrets/appa.yaml";
        };

        systemd.tmpfiles.rules = [
          "d ${stagingBase}     0700 root root - -"
          "d /mnt/media/restic  0700 root root - -"
        ]
        ++ map (n: "d ${stagingBase}/${n} 0700 root root - -") (lib.attrNames withStaging)
        ++ lib.optionals cfg.offsite.enable [
          "d /var/lib/restic-rclone 0700 root root - -"
        ];

        services.restic.backups = {
          local = commonBackup // {
            repository = "/mnt/media/restic/appa";
            timerConfig = {
              OnCalendar = "*-*-* 05:00:00";
              RandomizedDelaySec = "30m";
              Persistent = true;
            };
          };
        }
        // lib.optionalAttrs cfg.offsite.enable {
          # Restic-via-rclone repo. `gdrive` is the remote name in the
          # rclone.conf below; restic invokes rclone to read/write it.
          gdrive = commonBackup // {
            repository = "rclone:gdrive:restic/appa";
            rcloneConfigFile = "/var/lib/restic-rclone/rclone.conf";
            # Offset from local so the two timers don't fight for the
            # repo lock or re-run pg_dump simultaneously. Each repo runs
            # prepare/cleanup independently; the redundant pg_dump is
            # cheap compared to the upload itself.
            timerConfig = {
              OnCalendar = "*-*-* 07:00:00";
              RandomizedDelaySec = "60m";
              Persistent = true;
            };
          };
        };
      };
    };
}
