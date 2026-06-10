{ self, ... }:
{
  flake.nixosModules.restic =
    { config, ... }:
    # Nightly encrypted backups to Google Drive via the restic+rclone backend.
    # Restic doesn't support Drive natively; rclone exposes it as a generic
    # remote and restic talks to that. Drive caps the upload API at ~750 GB/day
    # per project, so an initial seed of /mnt/data (~670 GB) finishes in one
    # window if upstream is fast enough, or resumes the next day if not.
    #
    # /mnt/config / /var/lib/<svc> aren't included on purpose -- the *arr
    # stack stores live SQLite state there. Capturing it consistently would
    # need a stop/tar/start dance per service (separate "service-snapshots"
    # feature, TODO). For now, immich's own pg_dump output lands in
    # /mnt/data/immich/backups (enable in admin UI), so its database
    # restores consistently from what restic captures.
    #
    # Four jobs share the same Drive repo; restic's repository lock makes
    # accidental overlap safe (the later runner waits or fails). They're
    # spaced out by an hour to avoid that even when calendars collide
    # (e.g., the 1st of the month falling on a Saturday).
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

      # Resource caps. Restic's compress+encrypt path is CPU-bound and its
      # streaming reads are IO-bound; uncapped, a backup window can starve
      # an early-morning jellyfin client whose CPU lands on the same cores.
      # CPUQuota=200% lets it sprint to two cores when nothing else needs
      # them; weight=30 forces it to yield under contention.
      #
      # MemoryHigh (soft cap, kernel throttles reclaim above it) vs MemoryMax
      # (hard cap, OOM kill): the initial seed of /mnt/data wants ~800MB for
      # restic's pack assembly + rclone's upload buffers + the kernel's page
      # cache of the source files. At MemoryHigh=10% the cgroup hit the soft
      # cap constantly and spent more time reclaiming pages than uploading.
      # 15% gives the seed room to breathe; nightly incrementals use ~200MB
      # so the higher soft cap is a no-op in steady state. The hard ceiling
      # at 20% (1.5GB on 8GB) is unchanged -- still bounds the worst case.
      caps = {
        CPUWeight = 30;
        CPUQuota = "200%";
        IOWeight = 30;
        MemoryHigh = "15%";
        MemoryMax = "20%";
      };
    in
    {
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

          # rclone.connections=4: parallel HTTP/2 streams to Drive. Default
          # is a single stream that caps at ~100-200 Mbps regardless of pipe
          # width. With 771 Mbps upstream we were using ~14% of headroom on
          # one stream; four streams should push 400-600 Mbps. Each in-flight
          # upload buffers ~chunk_size (set in rclone.conf via sops), so
          # 4 * 64M = ~256MB extra in restic's cgroup -- fits inside the
          # MemoryHigh=15% / MemoryMax=20% caps.
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
        # Splitting prune off the nightly job keeps the nightly window short
        # -- prune reads pack metadata and on a 670GB+ repo can run 10-30min.
        # paths/dynamicFilesFrom/command all unset => the unit skips the
        # `restic backup` step and runs only `restic forget --prune`.
        #
        # Retention: 7d/4w/12m/5y matches "active mistake window + monthly
        # checkpoint year + multi-year capstone." Restic dedup keeps the
        # marginal cost of older snapshots near-zero for mostly-static data
        # like photos.
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
        # `restic check` validates structure: snapshot/tree/pack metadata --
        # catches local cache rot, corrupt pack indexes, and missing packs.
        # Does NOT re-read pack contents (that's appa-check-data below).
        # Scheduled Saturday so it precedes Sunday's prune; if prune ever
        # corrupts a pack, the next Saturday's run catches it within a week.
        appa-check = sharedRepo // {
          checkOpts = [ "--with-cache" ];
          timerConfig = {
            OnCalendar = "Sat *-*-* 08:30:00";
            Persistent = true;
            RandomizedDelaySec = "15min";
          };
        };

        # --- Job 4: monthly data-subset integrity check ----------------------
        # `--read-data-subset=1%` actually downloads + verifies SHA256 of a
        # random 1% of pack contents. Catches silent bit-rot in cloud
        # storage that metadata-only checks would miss. On a 670GB repo
        # that's ~6.7GB of Drive egress per run -- well within Drive's
        # daily API allowance. Bump to 5-10% if you ever hit corruption
        # and want stronger sampling.
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
