# Restic backup — work in progress

Branch: `feature/restic-backup`

## What's done

Per-service backup contributions aggregated by a new `restic` feature module.

- `modules/features/system/restic.nix` (new) — declares `options.services.backup.{enable,offsite,targets}`, builds `services.restic.backups.local` (always) and `services.restic.backups.gdrive` (when `offsite.enable = true`).
- Each NAS service module contributes a `services.backup.targets.<name>` block with `paths`, `exclude`, `prepareCommand`, `cleanupCommand`. `$STAGING` is set per-target to `/var/backup/restic-staging/<name>` and auto-included in the snapshot.
- `modules/profiles/nas.nix` — imports `restic`, sets `services.backup.enable = true`, `services.backup.offsite.enable = true`, and adds a `user-data` target for `/mnt/data`.

Targets contributed:
- **immich** — `pg_dump -Fc` of Immich DB + `mediaLocation`, minus `thumbs` / `encoded-video`
- **plex** — SQLite `.backup` of `library.db` + `library.blobs.db`, files minus Cache/Logs/Crash Reports + live DBs
- **jellyfin** — SQLite `.backup` of `jellyfin.db` + `library.db`, files minus transcodes/cache/log + live DBs
- **sonarr / radarr / prowlarr / bazarr** — SQLite `.backup` of `<service>.db` + dataDir
- **qbittorrent** — file-level (atomic `.fastresume`)
- **forgejo** — `services.forgejo.dump.backupDir` (forgejo manages its own 30-day retention). *forgejo itself is still commented out in profile-nas; target activates when forgejo does.*
- **user-data** — `/mnt/data` catch-all (declared at profile level)

Schedule: local at 05:00, gdrive at 07:00, retention `7 daily / 4 weekly / 12 monthly / 3 yearly`.

Evaluation passes (`nix eval .#nixosConfigurations.appa.config.services.backup.targets`).

## Next session — before this runs

1. **Add restic password to sops**
   ```
   sops secrets/appa.yaml
   ```
   Add `restic_password:` with a long random string. Same value will be used for both local and gdrive repos.

2. **Re-encrypt sops to appa's host key** (after appa is installed and its `/etc/ssh/ssh_host_ed25519_key` exists)
   - Derive its age key: `nix-shell -p ssh-to-age --run "ssh-to-age -i appa-host-key.pub"`
   - Replace the placeholder `age1...` value of `&appa` in `.sops.yaml:5`-ish (currently commented out at `.sops.yaml:43`)
   - Uncomment `- *appa` under `secrets/appa.yaml`'s creation rule
   - Run `sops updatekeys secrets/appa.yaml` (and same for any other file that should include appa)

3. **Bootstrap rclone on the host** (one-time, interactive)
   ```
   sudo install -d -m 0700 /var/lib/restic-rclone
   sudo rclone config --config /var/lib/restic-rclone/rclone.conf
   ```
   Create a remote of type `drive`, name it exactly `gdrive`. OAuth flow opens a browser. The repo will live at `gdrive:restic/appa`. Token refreshes write back to this file — keeping it off sops avoids the read-only refresh trap.

4. **Verify Jellyfin DB path assumption**
   `modules/features/media/jellyfin.nix` assumes the SQLite DBs live at `${dataDir}/data/{jellyfin,library}.db`. That's the standard 10.10+ layout. Check on a running install before activating:
   ```
   sudo ls /var/lib/jellyfin/data/*.db
   ```
   The `[ -f "$src" ] || continue` guard means missing files don't break the run, but they'd silently skip too.

5. **VM smoke-test before applying to appa**
   ```
   nix run .#appa-vm
   ```
   Inside the VM, manually fire the backup and check it produces a snapshot:
   ```
   sudo systemctl start restic-backups-local.service
   sudo journalctl -u restic-backups-local.service
   sudo -E restic -r /mnt/media/restic/appa --password-file /run/secrets/restic_password snapshots
   ```

6. **Full check**
   ```
   nix flake check
   ```

## Open decisions / things to revisit

- **Module dedup didn't work** when each service imported `self.nixosModules.restic` — got `services.backup.targets is already declared`. Worked around by importing restic only via `profile-nas`, matching the reverse-proxy pattern. Worth investigating why dedup failed for restic specifically if we ever want service modules to be reusable on non-NAS hosts. Possible causes to check: flake-parts re-wrapping the function, or option-declaration modules behaving differently from pure-config modules under dedup.
- **First-run cost** — initial backup uploads the full photo library to gdrive. Photos at scale may exceed gdrive free-tier (15 GB). If so, switch repo to B2 / rsync.net (one-line change: `repository = "b2:bucket-name:appa"` + an `environmentFile` with B2 creds). The rest of the module is backend-agnostic.
- **Plex/Jellyfin metadata size** — currently included (excluding only Cache/Logs/Crash Reports). Metadata can be tens of GB on a large library. If gdrive bloats, add `Metadata/` to excludes — re-fetching it triggers slow re-scans but the DB still has the references.
- **CrowdSec local DB** — not currently backed up. Could add a `services.backup.targets.crowdsec` contribution to `modules/features/network/crowdsec.nix` if we want to preserve decisions/banlists across restore.

## Reminders / contracts established this session

- `services.backup.targets.<name>` is the contribution point. `prepareCommand` runs with `$STAGING` set; the dir is auto-created and auto-included in the snapshot. Service modules must NOT import restic directly — restic is imported once via `profile-nas` so dedup doesn't trip.
- `runuser -u postgres -- pg_dump` for Postgres dumps; `sqlite3 ".backup ..."` for SQLite — both online, no service stop required.
- All dump files are emitted under `$STAGING/<name>/...`, cleaned up by each target's `cleanupCommand` after restic walks the tree.
