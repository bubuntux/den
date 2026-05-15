# appa: Fedora CoreOS → NixOS migration

Drafted: 2026-05-15

Migration of the `appa` NAS from Fedora CoreOS (podman + quadlets) to NixOS
using this flake's `profile-nas`. The existing LVM volumes (`config`, `data`,
`media` in VG `nas`) are preserved unmodified; only `/dev/sda` gets
repartitioned for the new root.

## Pre-flight inventory (verified on FCOS 2026-05-15)

### Disk layout

| Device | Size | Role | Touch during install? |
|--------|------|------|----------------------|
| `/dev/sda` | 465.8G SSD | FCOS root (sda1-5) + 395G free (sda6) | **YES — wipe for NixOS** |
| `/dev/sdb` | 9.1T | PV in `nas` VG (leg of `media`) | NO |
| `/dev/sdc` | 3.6T | PV in `nas` VG (leg of `data`) | NO |
| `/dev/sdd` | 3.6T | PV in `nas` VG (leg of `config`) | NO |
| `/dev/sde` | 3.6T | PV in `nas` VG (legs of `data` + `config`) | NO |
| `/dev/sdf` | 9.1T | PV in `nas` VG (leg of `media`) | NO |

**Critical:** when running `nixos-install`, target by `/dev/disk/by-id/...`
for the SSD, not `/dev/sda`. Linux can reorder `sdX` letters across reboots.

### LVM state (verified 100% sync, healthy)

| LV | Type | Size | UUID | FCOS mount | NixOS mount (per `appa.nix:71-87`) |
|----|------|------|------|------------|-----------------------------------|
| `config` | raid1 (sdd+sde) | 200G | `5cac8340-4635-4ec4-bec5-b3642c16d1a3` | `/var/mnt/config` | `/mnt/config` |
| `data` | raid1 (sdc+sde) | 1.27T | `5bc48131-4c99-43df-b866-c994f526b403` | `/var/mnt/data` | `/mnt/data` |
| `media` | linear (sdb+sdf) | 18.2T | `0a1c1b48-cd6e-48bd-823c-d1c30a1c5f99` | `/var/mnt/media` | `/mnt/media` |

`media` is NOT mirrored — single-disk failure on sdb or sdf loses all 18T.

### Actual usage

| Path | Size | Notes |
|------|------|-------|
| `/var/mnt/config` | 43G / 196G | 27G of it is Plex metadata/cache |
| `/var/mnt/data` | 1002G / 1.3T | Repos, bkp, google_takeout (huge), docs, ssh |
| `/var/mnt/media` | 16T / 19T | movies 8.2T, tv 6.2T, downloads 815G, roms 612G |

### Services running on FCOS

`bazarr`, `crowdsec`, `gluetun`, `jellyfin`, `prowlarr`, `qbittorrent`,
`radarr`, `sonarr`, `tvheadend`, `plex`, `swag`, `ddns`, `cockpit-ws`.

Cold (data dir exists, not running): `home-assistant`, `vaultwarden`,
`gitea`, `freshrss`, `syncthing`, `cabernet`, `whatsapp`, `wireguard`,
`protorrent`.

### Already applied in repo

- `appa.nix:41-45` — added `dm-raid` + `raid1` to `boot.kernelModules` so
  systemd can assemble the LVM RAID mirrors post-boot.

---

## Backup plan (pre-install)

Goal: one-shot snapshot of `/var/mnt/config` to zuko so a botched install
doesn't lose service state. Decisions: pull via rsync, stop services for a
clean snapshot, keep on zuko until new appa is verified.

### Step 1 — Prep target on zuko

```bash
mkdir -p /home/bbtux/backups/appa-config-pre-nixos-2026-05-15
```

(Under `/home` so it survives reboots and isn't tmp-cleaned. zuko has 556G
free on `/`, plenty for a ~10G post-exclude footprint.)

### Step 2 — Stop service containers on appa

```bash
ssh core@appa 'sudo systemctl stop \
  bazarr crowdsec gluetun jellyfin prowlarr \
  qbittorrent radarr sonarr tvheadend plex swag ddns'

# verify nothing is still writing under /var/mnt/config
ssh core@appa 'sudo lsof +D /var/mnt/config 2>/dev/null | head'
```

Cold services (home-assistant et al.) are already stopped — no action.

### Step 3 — Sanity-check exclude paths before rsync

Rsync silently includes excluded paths that don't match exactly (case,
trailing slash, etc.). Eyeball once:

```bash
ssh core@appa 'sudo ls "/var/mnt/config/plex/Library/Application Support/Plex Media Server/"'
ssh core@appa 'sudo ls /var/mnt/config/jellyfin/'
```

Confirm dirs `Cache`, `Metadata`, `Media`, `Logs`, `Crash Reports`,
`Diagnostics`, `Updates` exist under Plex, and lowercase `cache`,
`metadata`, `log` under Jellyfin.

### Step 4 — rsync pull

From zuko:

```bash
rsync -aHAX --info=progress2 --human-readable \
  --exclude='plex/Library/Application Support/Plex Media Server/Cache/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Metadata/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Media/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Logs/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Crash Reports/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Diagnostics/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Updates/' \
  --exclude='jellyfin/cache/' \
  --exclude='jellyfin/metadata/' \
  --exclude='jellyfin/log/' \
  core@appa:/var/mnt/config/ \
  /home/bbtux/backups/appa-config-pre-nixos-2026-05-15/
```

Flag notes:
- `-a` archive (perms, times, symlinks, ownership)
- `-H` hard links (cheap insurance)
- `-A -X` preserve ACLs + xattrs (incl. SELinux labels — inert on NixOS,
  harmless to carry)
- Trailing `/` on source = copy contents not the dir itself
- No `--delete` (fresh dir)

Kept (irreplaceable):
- Plex: `Preferences.xml`, `Plug-in Support/Databases/*.db`,
  `Plug-in Support/Preferences/`, `Plug-ins/`
- Jellyfin: `data/` (library SQLite), `config/`, `plugins/`, `root/`

Dropped (rebuildable on first scan, costs hours of agent traffic but no
data loss): artwork/metadata caches, transcoding caches, logs.

### Also grab these (small, invaluable as reference)

```bash
# Quadlet/systemd unit files — reference when porting to NixOS modules
ssh core@appa 'sudo tar czf - /etc/containers/' \
  > /home/bbtux/backups/appa-config-pre-nixos-2026-05-15/_etc-containers.tar.gz
ssh core@appa 'sudo tar czf - /etc/systemd/system' \
  > /home/bbtux/backups/appa-config-pre-nixos-2026-05-15/_etc-systemd-system.tar.gz

# SSH host keys — keeps appa's identity stable for clients; sops-nix age key
# derives from these
ssh core@appa 'sudo tar czf - /etc/ssh/ssh_host_*' \
  > /home/bbtux/backups/appa-config-pre-nixos-2026-05-15/_ssh-host-keys.tar.gz
```

### Step 5 — Verify

```bash
# size sanity
du -sh /home/bbtux/backups/appa-config-pre-nixos-2026-05-15
ssh core@appa 'sudo du -sh /var/mnt/config'   # source will be larger by excluded amount

# checksum dry-run — should report 0 files needing transfer
rsync -aHAXn --checksum --info=stats2 \
  --exclude='plex/Library/Application Support/Plex Media Server/Cache/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Metadata/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Media/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Logs/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Crash Reports/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Diagnostics/' \
  --exclude='plex/Library/Application Support/Plex Media Server/Updates/' \
  --exclude='jellyfin/cache/' \
  --exclude='jellyfin/metadata/' \
  --exclude='jellyfin/log/' \
  core@appa:/var/mnt/config/ \
  /home/bbtux/backups/appa-config-pre-nixos-2026-05-15/
```

### Step 6 — Restart on appa (only if install not immediate)

```bash
ssh core@appa 'sudo systemctl start \
  gluetun jellyfin plex bazarr crowdsec prowlarr \
  qbittorrent radarr sonarr tvheadend swag ddns'
```

`gluetun` first — qbittorrent depends on it.

### Retention

Keep `/home/bbtux/backups/appa-config-pre-nixos-2026-05-15/` on zuko until
new appa is fully verified (~1-2 weeks of confirmed-working services).
Then either delete or promote into an ongoing borg/restic job as part of
the NixOS config.

---

## After backup — still to plan

These are pending and not part of the backup phase. Decisions/work
remaining before the install runbook is complete:

1. **Bind-mounts for service state** — wire `/mnt/config/<service>` →
   `/var/lib/<service>` for each NixOS service module (default dataDir
   doesn't point at the LV).
2. **UID alignment** — chown each service dir to the matching NixOS service
   user after first activation. Document the post-install chown step here.
3. **Install target by-id** — record the SSD's `/dev/disk/by-id/...` so
   `nixos-install` can never pick the wrong disk.
4. **Fill in TODO UUIDs** — `appa.nix:57,62,90` for `/`, `/boot`, swap
   after partitioning sda.

---

## Decided: services in scope

### Migrate (port to NixOS, restore data, bind-mount config dir)

| Service | NixOS module | Data dir on LV |
|---------|-------------|----------------|
| jellyfin | `features/media/jellyfin.nix` | `jellyfin/` |
| plex | `features/media/plex.nix` | `plex/` |
| sonarr | `features/arr/sonarr.nix` | `sonarr/` |
| radarr | `features/arr/radarr.nix` | `radarr/` |
| bazarr | `features/arr/bazarr.nix` | `bazarr/` |
| prowlarr | `features/arr/prowlarr.nix` | `prowlarr/` |
| qbittorrent | `features/arr/qbittorrent.nix` | `protorrent/`? confirm path |
| gluetun (VPN) | `features/arr/vpn-media.nix` + vpn-confinement | `gluetun/` |
| crowdsec | (already in profile-nas) | `crowdsec/` |
| cloudflare-ddns | `features/network/cloudflare-ddns.nix` | (no on-disk state) |
| caddy (replaces `swag`) | `features/network/reverse-proxy.nix` | (no on-disk state) |

### Drop (do not port, archive data dir under `_archive/`)

- **tvheadend** — running on FCOS but no longer used. 883M.
- **home-assistant** — cold. 1.9G.
- **vaultwarden** — cold. 4.8M.
- **gitea** — cold. 123M. `forgejo` is commented out in `profile-nas`.
- **freshrss** — cold. 3.6M.
- **syncthing** — cold. 121M.
- **cabernet** — cold. 304M.
- **whatsapp** — cold. 40K.
- **wireguard** / **wireguard_bkp** — cold. ~100K.
- **protorrent** — cold (likely old qbittorrent path). 21M.
- **swag** — replaced by caddy; config is throwaway. 157M.

Total to archive: ~3.7G — negligible on a 200G LV.

---

## Decided: mount paths + container-path migration

### Host mount points: keep `/mnt/{config,data,media}`

As declared in `appa.nix:71-87`. NixOS-conventional, simpler than the
FCOS `/var/mnt/...` quirk (which only exists because OSTree's `/mnt` is
read-only — irrelevant on NixOS).

### The container-path problem

Plex/Jellyfin library DBs and *arr/qBittorrent root-folder configs have
**container-internal paths** baked in (e.g., `/data/movies`, `/downloads`,
`/tv`). On FCOS, podman volume mounts translate these to host paths
(`/var/mnt/media/movies`, etc.). On NixOS, services run **natively** — no
container translation happens, so the baked paths resolve against the
literal NixOS root.

### Strategy: bind-mounts first, UI-remap later

Phased migration. Bring services up with library data intact, then remap
paths in each service's UI over days/weeks.

#### Step 1 — Discover container paths on FCOS (do BEFORE install)

```bash
ssh core@appa 'for c in plex jellyfin sonarr radarr bazarr prowlarr qbittorrent gluetun; do
  echo "=== $c ==="
  sudo podman inspect "$c" --format "{{range .Mounts}}{{.Destination}} <- {{.Source}}{{println}}{{end}}"
done'
```

Record each unique `Destination` path. Expected patterns:
- Plex: `/data` → media, `/config` → plex config
- Jellyfin: `/media` (or `/data`) → media
- Sonarr/Radarr: `/tv`, `/movies`, `/downloads`
- qBittorrent: `/downloads`

Save the output into this file under a "Discovered container paths"
subsection before proceeding.

#### Step 2 — Add bind-mount entries to `appa.nix`

Prefer declarative `fileSystems` bind-mounts over symlinks — they're
reproducible from `nixos-rebuild`, fail loud if source is missing, and are
trivial to remove later.

Template (concrete paths filled in from Step 1 discovery):

```nix
# Container-path compatibility shims. Remove these once Plex/Jellyfin/*arr
# library paths have been remapped via their UIs to /mnt/media/...
fileSystems."/data" = {
  device = "/mnt/media";
  options = [ "bind" "nofail" ];
};
fileSystems."/downloads" = {
  device = "/mnt/media/downloads";
  options = [ "bind" "nofail" ];
};
# ...one entry per unique Destination from Step 1
```

#### Step 3 — UI remap, one service at a time (post-install)

After services come up and libraries are confirmed working through the
shim paths:

- **Plex**: Library → "Edit Library" → **Add** new folder under
  `/mnt/media/...` first → scan → **then remove** old folder. Order
  matters: watched-state is GUID-matched, but removing the old path
  before the new one is scanned can blank out user overrides (custom
  posters, title edits).
- **Jellyfin**: Dashboard → Libraries → edit folders. Same add-scan-remove
  order.
- **Sonarr / Radarr**: add new Root Folder under `/mnt/media/...`, then
  **Mass Editor** → select all → change Root Folder → apply. Do not
  remove old root folder until Mass Editor reports zero items still on it.
- **Bazarr**: follows Sonarr/Radarr via API; its paths update automatically
  once *arr roots are migrated.
- **qBittorrent**: trickiest because in-progress torrents have absolute
  paths in per-torrent `.fastresume` / `.json` files. Either:
  - Change default save path in Preferences → bulk-select all torrents →
    right-click → "Set Location" → new path (qBittorrent rewrites
    fastresume entries), or
  - Leave the `/downloads` bind-mount permanent and only migrate the
    *default* save path so new torrents land on the canonical path.

#### Step 4 — Remove the shims

When every service shows native `/mnt/media/...` paths in its UI (verify
by spot-checking library item details), delete the `fileSystems."/data"`
etc. blocks from `appa.nix` and `nixos-rebuild switch`. Mounts go away;
services keep working because nothing references them.

---

### Post-install cleanup (run from new appa as root, after services verified)

```bash
sudo mkdir -p /mnt/config/_archive
for d in tvheadend home-assistant vaultwarden gitea freshrss syncthing \
         cabernet whatsapp wireguard wireguard_bkp protorrent swag; do
  [ -e "/mnt/config/$d" ] && sudo mv "/mnt/config/$d" /mnt/config/_archive/
done
sudo ls -la /mnt/config /mnt/config/_archive
```

Defer this until after the migrated services have been running successfully
for a few days — easier to un-archive than to undo a delete. The pre-install
backup on zuko has these too, so even an accidental `rm -rf _archive` is
recoverable.
