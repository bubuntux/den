{ self, ... }:
{
  flake.modules.nixos.restic =
    { config, ... }:
    # Nightly encrypted backups to Google Drive (restic has no native Drive
    # backend; rclone exposes it as a generic remote). Drive caps uploads at
    # ~750 GB/day, so the initial ~670 GB seed fits one window or resumes.
    #
    # /mnt/config and /var/lib/<svc> are excluded on purpose: the *arr stack
    # keeps live SQLite there and would need a stop/tar/start dance per service
    # (TODO). immich is fine -- its own pg_dump lands in a backed-up path.
    #
    # Four jobs share one repo, spaced an hour apart so colliding calendars
    # never race for the repository lock:
    #
    #   restic-backups-appa.service            daily 06:30        backup only
    #   restic-backups-appa-prune.service      Sun  07:30         forget+prune
    #   restic-backups-appa-check.service      Sat  08:30         metadata check
    #   restic-backups-appa-check-data.service monthly 1st 09:30  1% data check
    #
    # Manual one-time prereqs:
    #   1. `rclone config` on a workstation -> add a Drive remote named
    #      `gdrive`, copy the resulting block from ~/.config/rclone/rclone.conf
    #      into secrets/appa.yaml as `rclone_gdrive_conf`
    #   2. `openssl rand -base64 48` -> store as `restic_password`. Keep an
    #      offline copy; losing it makes the backup unrecoverable.
    let
      # Repo/credentials shared by all three jobs.
      sharedRepo = {
        repository = "rclone:gdrive:restic-appa";
        passwordFile = config.sops.secrets.restic_password.path;
        rcloneConfigFile = config.sops.secrets.rclone_gdrive_conf.path;
      };

      # Sprints to two cores when idle, yields under contention -- an uncapped
      # backup window starves an early-morning jellyfin client. MemoryHigh is
      # 15% because the seed wants ~800MB and spent more time reclaiming than
      # uploading at 10%; incrementals use ~200MB, so it is a no-op in steady
      # state.
      caps = {
        CPUWeight = 30;
        CPUQuota = "200%";
        IOWeight = 30;
        MemoryHigh = "15%";
        MemoryMax = "20%";
      };
    in
    {
      key = "den:nixos.restic";
      sops.secrets.restic_password.sopsFile = "${self}/secrets/appa.yaml";
      sops.secrets.rclone_gdrive_conf.sopsFile = "${self}/secrets/appa.yaml";

      services.restic.backups = {
        # --- Job 1: nightly backup -------------------------------------------
        # No prune/check here -- those are weekly/monthly jobs below.
        appa = sharedRepo // {
          paths = [ "/mnt/data" ];
          exclude = [
            # User's existing backup workflow writes here; don't double-cover
            # and don't risk an exclude-loop if they ever drop a restic
            # snapshot inside it.
            "/mnt/data/bkp"
            "/mnt/data/lost+found"
            # Generic cache / OS cruft.
            "**/.cache"
            "**/Trash"
            "**/.Trash-*"
            "**/.DS_Store"
            "Thumbs.db"
          ];
          extraBackupArgs = [
            # Honor CACHEDIR.TAG sentinels (cargo target/, nix-build result/,
            # etc.). Skip anything tagged regardless of path.
            "--exclude-caches"
            # Safety net: restic stops at /mnt/data's fs boundary. /mnt/media
            # is a sibling mount, but this also catches any nested bind mounts.
            "--one-file-system"
            # 32MB packs (default 16MB) halve API calls to Drive without a
            # meaningful downside on a residential fiber upstream.
            "--pack-size=32"
          ];

          # One stream caps at ~100-200 Mbps regardless of pipe width. Four
          # buffer ~256MB extra, which fits the caps above.
          extraOptions = [
            "rclone.connections=4"
          ];

          # First scheduled run will `restic init` the repo on Drive. No-op
          # on subsequent runs.
          initialize = true;

          # 06:30 sits clear of appa's auto-upgrade reboot window (Sundays
          # 03:00-05:00, see modules/hosts/appa.nix) and before household
          # streaming picks up. RandomizedDelaySec keeps repeated misses from
          # piling onto an exact clock tick.
          timerConfig = {
            OnCalendar = "06:30";
            Persistent = true;
            RandomizedDelaySec = "15min";
          };
        };

        # --- Job 2: weekly forget+prune --------------------------------------
        # Split off the nightly job, which prune would stretch by 10-30min.
        # Leaving paths/dynamicFilesFrom/command unset is what makes the unit
        # skip `restic backup` and run only `forget --prune`.
        appa-prune = sharedRepo // {
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 12"
            "--keep-yearly 5"
          ];
          timerConfig = {
            OnCalendar = "Sun *-*-* 07:30:00";
            Persistent = true;
            RandomizedDelaySec = "15min";
          };
        };

        # --- Job 3: weekly metadata integrity check --------------------------
        # Metadata only, no pack contents (that is job 4). Saturday, so it
        # precedes Sunday's prune and catches prune damage within a week.
        appa-check = sharedRepo // {
          checkOpts = [ "--with-cache" ];
          timerConfig = {
            OnCalendar = "Sat *-*-* 08:30:00";
            Persistent = true;
            RandomizedDelaySec = "15min";
          };
        };

        # --- Job 4: monthly data-subset integrity check ----------------------
        # Downloads and verifies 1% of pack contents, catching bit-rot that
        # metadata checks miss: ~6.7GB of egress. Raise it after a corruption.
        appa-check-data = sharedRepo // {
          checkOpts = [
            "--with-cache"
            "--read-data-subset=1%"
          ];
          timerConfig = {
            OnCalendar = "*-*-01 09:30:00";
            Persistent = true;
            RandomizedDelaySec = "15min";
          };
        };
      };

      systemd.services = {
        restic-backups-appa = {
          unitConfig.RequiresMountsFor = [ "/mnt/data" ];
          serviceConfig = caps;
        };
        restic-backups-appa-prune.serviceConfig = caps;
        restic-backups-appa-check.serviceConfig = caps;
        restic-backups-appa-check-data.serviceConfig = caps;
      };
    };
}
