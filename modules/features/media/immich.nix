{
  flake.nixosModules.immich =
    { lib, ... }:
    let
      port = 2283;
      mediaLocation = "/mnt/data/immich";
      # Immich verifies a `.immich` sentinel in each of these subdirs on
      # startup; pre-seed them so the integrity check passes on a custom
      # mediaLocation (with the default /var/lib/immich the upstream
      # bootstrap creates them, but with mountChecks already enabled in the
      # DB the verify runs before that path).
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
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
        # Disabled on appa (8 GB RAM): CLIP + face + OCR models peak ~3 GB
        # which collides with the rest of the media stack. Re-enable once
        # the host has more RAM or moves to a beefier box. If you re-enable,
        # also add LimitCORE=0 to immich-machine-learning.service (see the
        # serviceConfig override below for the rationale).
        machine-learning.enable = false;
        inherit port mediaLocation;
        # Expose the Intel iGPU render node to immich-server so ffmpeg can
        # use VA-API for transcoding. Default `[ ]` sets PrivateDevices=true
        # on the unit, which hides /dev/dri entirely. The codec path
        # (VAAPI vs. QSV vs. disabled) is still chosen in the Immich admin
        # UI under Video Transcoding -- this option only grants access.
        accelerationDevices = [ "/dev/dri/renderD128" ];
      };

      # accelerationDevices only handles the systemd DeviceAllow side; the
      # render node is `crw-rw---- root:render` so ffmpeg still needs group
      # membership to open it. Mirrors the jellyfin setup -- same iGPU, same
      # failure mode (silent fallback to CPU transcoding) without these.
      users.users.immich.extraGroups = [
        "render"
        "video"
      ];

      # Cap the immich slice so a runaway import job can't OOM-lock the
      # host or starve other services of CPU/IO. immich-server (and any
      # spawned sharp/ffmpeg subprocesses) inherit these limits via the
      # cgroup; if machine-learning is re-enabled it joins the same slice.
      # Reason: 2026-05-22 kernel page-fault BUG + 11-min I/O storm during
      # bulk photo ingest on an 8 GB-RAM / 4-core J5040 host.
      systemd.slices.system-immich.sliceConfig = {
        # Memory: hard cap below host-OOM territory; let the kernel reclaim
        # aggressively from 3G upward; bound swap usage so a leak can't
        # exhaust the swap device either.
        MemoryHigh = "3G";
        MemoryMax = "4G";
        MemorySwapMax = "2G";
        # CPU: at most 2 of 4 cores. Leaves headroom for jellyfin/plex
        # transcodes, sshd, kernel work — so a bulk ingest can't lock the
        # host's interactive shell again. CPUWeight=50 (default is 100)
        # means other slices win under contention.
        CPUQuota = "200%";
        CPUWeight = 50;
        # IO: best-effort throttle. Honoured by BFQ / io.cost-enabled
        # schedulers; a no-op (but harmless) on the stock mq-deadline.
        IOWeight = 50;
      };

      # Refuse to start immich-server if the mediaLocation mount is missing.
      # On 2026-05-22 the systemd-fsck for /mnt/data was SIGTERMed mid-journal-
      # recovery on boot, the mount unit went inactive, and immich-server
      # happily started anyway — writing uploads to the (empty) /mnt/data
      # stub on the root filesystem and leaving the real library on the RAID
      # array invisible. RequiresMountsFor pulls in the mount unit's
      # Requires + After and fails the service if the mount can't activate.
      systemd.services.immich-server = {
        unitConfig.RequiresMountsFor = mediaLocation;
        # Suppress core dumps. When the slice OOM-killed the ML worker on
        # 2026-05-22, systemd-coredump tried to write a multi-GB core file
        # and saturated the disk for 11 min, hanging logins and TTY getties.
        # RLIMIT_CORE=0 tells the kernel to skip the dump entirely.
        serviceConfig.LimitCORE = 0;
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
        inherit port;
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

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
