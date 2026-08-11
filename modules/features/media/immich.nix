{ self, inputs, ... }:
{
  flake.modules.nixos.immich =
    { lib, pkgs, ... }:
    let
      port = 2283;
      mediaLocation = "/mnt/data/immich";
      # Immich verifies a `.immich` sentinel in each on startup, and on a custom
      # mediaLocation that check runs before the bootstrap that would create it.
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
      key = "den:nixos.immich";
      imports = [ self.modules.nixos.media-registry ];

      den.media.services.immich = {
        inherit port;
        unit = "immich-server";
        # Library lives on /mnt/data/immich, not the shared /mnt/media tree, so
        # no `media` group and a different mount to wait for.
        mediaGroup = false;
        requiresMounts = [ mediaLocation ];
        # Caps are applied to the whole system-immich slice below rather than to
        # a single unit, so the registry leaves cgroup settings alone here.
        resources = null;
      };

      services.immich = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
        # Immich refuses to downgrade, so a stable channel frozen on 2.x strands
        # the library there; the 26.05 backport is stalled (nixpkgs#539560). The
        # module is identical across channels, so only the package crosses.
        package =
          (import inputs.nixpkgs-unstable {
            inherit (pkgs.stdenv.hostPlatform) system;
          }).immich;
        # Models peak ~3 GB, and ML alone could eat the slice budget during a
        # backfill; the per-service caps below keep browsing responsive.
        machine-learning.enable = true;
        inherit port mediaLocation;
        # The default `[ ]` sets PrivateDevices=true and hides /dev/dri. This
        # only grants access; the codec path is chosen in the admin UI.
        accelerationDevices = [ "/dev/dri/renderD128" ];
      };

      # DeviceAllow is only half of it: the render node is root:render, so
      # without the group ffmpeg silently falls back to CPU transcoding.
      users.users.immich.extraGroups = [
        "render"
        "video"
      ];

      # Added after a 2026-05-22 kernel page-fault BUG and 11-minute I/O storm
      # during a bulk ingest. Subprocesses inherit these through the cgroup.
      systemd.slices.system-immich.sliceConfig = {
        # Percentages so the caps scale with the hardware. MemorySwapMax's % is
        # relative to physical RAM (systemd quirk).
        MemoryHigh = "35%";
        MemoryMax = "50%";
        MemorySwapMax = "25%";
        # CPUQuota is per-core absolute (200% = 2 cores). Weight 100: above the
        # *arr scans at 75, below live streams at 150.
        CPUQuota = "200%";
        CPUWeight = 100;
        # IO: matches CPUWeight tier — interactive priority (default 100).
        # Activated by BFQ scheduler (see appa.nix udev rule); a no-op
        # on mq-deadline.
        IOWeight = 100;
      };

      # The registry's requiresMounts above is what refuses to start
      # immich-server when the mediaLocation mount is missing. On 2026-05-22 the
      # systemd-fsck for /mnt/data was SIGTERMed mid-journal-recovery on boot,
      # the mount unit went inactive, and immich-server happily started anyway —
      # writing uploads to the (empty) /mnt/data stub on the root filesystem and
      # leaving the real library on the RAID array invisible. RequiresMountsFor
      # pulls in the mount unit's Requires + After and fails the service if the
      # mount can't activate.
      systemd.services.immich-server = {
        # Suppress core dumps. When the slice OOM-killed the ML worker on
        # 2026-05-22, systemd-coredump tried to write a multi-GB core file
        # and saturated the disk for 11 min, hanging logins and TTY getties.
        # RLIMIT_CORE=0 tells the kernel to skip the dump entirely.
        serviceConfig.LimitCORE = 0;
      };

      # Per-service caps for the ML worker. system-immich.slice already
      # bounds the joint footprint; these constrain ML *within* the slice
      # so the server (CPUWeight=100 / IOWeight=100 defaults) keeps
      # priority for interactive browsing during a tagging backfill.
      # MemoryMax=35% (~2.8 G on 8 G RAM) is sized to the CLIP+face+OCR
      # peak; MemoryHigh=25% throttles softly before the hard cap. % is
      # relative to physical RAM, so caps auto-scale with hardware.
      # LimitCORE=0 mirrors immich-server -- same OOM-on-coredump risk.
      systemd.services.immich-machine-learning.serviceConfig = {
        LimitCORE = 0;
        MemoryHigh = "25%";
        MemoryMax = "35%";
        CPUWeight = 50;
        IOWeight = 50;
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
    };
}
