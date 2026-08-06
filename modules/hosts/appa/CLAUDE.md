# appa

The 4-core J5040 NAS. Repo-wide rules are in the root `CLAUDE.md`.

## Resource caps on appa

appa is a 4-core J5040 with 8 GB, and the services on it will happily starve one
another: a bulk immich ingest, a qbittorrent recheck and an \*arr library scan can
pin all four cores between them, at which point the kernel cannot flush its
journal and sshd stops answering even though nothing has OOM'd. Every service
therefore declares cgroup caps, mostly through `den.media.services`, and the
weights form one ladder that only makes sense read together:

| weight | services | why |
|---|---|---|
| 1000 | openssh | the machine must stay reachable to fix the rest |
| 150 | jellyfin, plex, tvheadend | live streams lose to nothing |
| 125 | crowdsec | ban decisions should stay timely under load |
| 100 | immich | interactive browsing, above background work |
| 75 | sonarr, radarr, prowlarr | library scans are background |
| 50 | qbittorrent, bazarr | bulk, yields to everything |
| 30 | restic | nightly backup window, yields hardest |

`IOWeight` follows the same number. Two conventions go with it: memory caps are
**percentages**, so they scale with a RAM upgrade rather than needing a revisit
(note `MemorySwapMax`'s percentage is relative to physical RAM, a systemd quirk),
and `CPUQuota` is per-core absolute — `200%` means two cores. The host also
reserves ~half a core through `systemd.settings.Manager.DefaultCPUAccounting`
and friends; see `hosts/appa/default.nix`.

A new service on appa picks its tier from the table rather than inventing a
number, and IO/CPU weights stay equal unless there is a reason.
