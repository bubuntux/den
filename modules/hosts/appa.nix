{
  inputs,
  self,
  ...
}:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.nixosConfigurations.appa = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      bundle-host
      profile-nas
      user-bbtux
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      (
        {
          config,
          lib,
          modulesPath,
          pkgs,
          ...
        }:
        {
          networking.hostName = "appa";
          system.stateVersion = "25.11";

          # Static ULA on eno1, in addition to SLAAC-derived ULA and public
          # global addresses. Gives services a stable, short internal address
          # to bind to. The router already announces fdf9:ef45:81dc:2200::/64,
          # so this is reachable from any LAN host without extra routes.
          networking.interfaces.eno1.ipv6.addresses = [
            {
              address = "fdf9:ef45:81dc:2200::a";
              prefixLength = 64;
            }
          ];

          # Without this, NixOS's dhcpcd module auto-emits `noipv6rs` for
          # any interface with a manually declared IPv6 address, which kills
          # SLAAC on eno1 — the public 2605:… and router-announced ULA stop
          # renewing and disappear after the lease expires. Forcing IPv6rs=true
          # keeps dhcpcd soliciting RAs so the static ULA and SLAAC coexist.
          networking.dhcpcd.IPv6rs = true;

          # Run unattended weekly: Sunday at 03:00 build the new generation,
          # stage as next-boot (operation=boot inherits from shared default),
          # then reboot if a kernel/initrd/systemd change requires it -- but
          # only within the 03:00-05:00 quiet window so we never reboot mid-
          # stream. randomizedDelaySec stays at the shared 15min default,
          # giving an effective run window of 03:00-03:15.
          system.autoUpgrade = {
            dates = "Sun *-*-* 03:00:00";
            allowReboot = true;
            rebootWindow = {
              lower = "03:00";
              upper = "05:00";
            };
          };

          # 4-core J5040 with limited RAM; keep build parallelism conservative
          # so Go-heavy builds (caddy + plugins) don't trigger OOM/kernel oops.
          nix.settings = {
            max-jobs = 1;
            cores = 2;
          };

          # Reserve ~half a core for the kernel, journald, sshd, and the
          # systemd hierarchy. Without this, an Immich post-migration
          # backfill (pinned to its 2-core slice cap) + a qbittorrent
          # recheck + an *arr library scan can collectively pin all 4
          # cores -- the kernel can't flush its journal, sshd stops
          # answering, and the box appears frozen even though no service
          # actually OOM'd. PSI's `cpu some=70%+` during the 2026-05-24
          # incident was the smoking gun. 350% = 4 cores * 100% - 50%
          # headroom; bump proportionally on hardware upgrades.
          systemd.slices.system.sliceConfig.CPUQuota = "350%";

          # Static server: override the shared locale module's geoclue-based
          # automatic timezone. The agent fails on a headless host because the
          # dbus policy bundled with timedated only grants set-timezone to
          # interactive (logind seat) callers.
          time.timeZone = "America/Chicago";
          services.automatic-timezoned.enable = lib.mkForce false;
          services.geoclue2.enable = lib.mkForce false;

          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          # --- Hardware / Kernel (Intel Pentium Silver J5040, SATA) ---
          # sda is /dev/disk/by-id/ata-WDC_WDS500G1R0A-68A4W0_233710800325
          boot.initrd.availableKernelModules = [
            "ahci"
            "xhci_pci"
            "usbhid"
            "usb_storage"
            "sd_mod"
          ];
          # dm-raid + raid1 must be in initrd, not just boot.kernelModules.
          # The udev-triggered lvm-activate-nas.service races the later
          # systemd-modules-load.service and fails with "raid1 target support
          # missing from kernel?" — only the linear `media` LV activates,
          # the raid1 `config` / `data` LVs are left offline.
          boot.initrd.kernelModules = [
            "dm-snapshot"
            "dm-raid"
            "raid1"
          ];
          boot.kernelModules = [ "kvm-intel" ];
          boot.extraModulePackages = [ ];

          # --- LVM support (systemd initrd handles dm modules automatically) ---
          boot.initrd.services.lvm.enable = true;
          services.lvm.enable = true;

          # Switch HDDs to the BFQ I/O scheduler so per-cgroup IOWeight
          # actually takes effect; the stock mq-deadline ignores weights.
          # Gated on rotational==1 so the SATA SSD (sda) keeps mq-deadline,
          # which is optimal for low-latency flash. BFQ has slightly higher
          # per-IO CPU overhead but trades that for fair-queueing across
          # services -- a worthwhile trade on a host where the *arr scans,
          # qbittorrent, and immich background jobs all share five HDDs.
          services.udev.extraRules = ''
            ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
          '';

          # --- Headless: disable plymouth, show boot messages ---
          boot.plymouth.enable = lib.mkForce false;
          boot.kernelParams = lib.mkForce [ "boot.shell_on_fail" ];
          boot.consoleLogLevel = lib.mkForce 3;

          # --- Filesystems ---
          fileSystems."/" = {
            device = "/dev/disk/by-uuid/312a5183-407c-4855-a6e1-ef5991765a19";
            fsType = "ext4";
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/7BD6-F122";
            fsType = "vfat";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          };

          # LVM volumes (UUIDs are stable -- these drives are NOT reformatted)
          fileSystems."/mnt/config" = {
            device = "/dev/disk/by-uuid/5cac8340-4635-4ec4-bec5-b3642c16d1a3";
            fsType = "ext4";
            options = [ "nofail" ];
          };

          fileSystems."/mnt/data" = {
            device = "/dev/disk/by-uuid/5bc48131-4c99-43df-b866-c994f526b403";
            fsType = "ext4";
            options = [ "nofail" ];
          };

          fileSystems."/mnt/media" = {
            device = "/dev/disk/by-uuid/0a1c1b48-cd6e-48bd-823c-d1c30a1c5f99";
            fsType = "ext4";
            options = [ "nofail" ];
          };

          # Mount-point ownership normalization. systemd-tmpfiles refuses to
          # create files under a path whose intermediate dirs are owned by a
          # non-trusted user (TOCTOU safety): any rule like `d /mnt/data/<svc>
          # 0700 <svc> <svc>` silently no-ops if /mnt/data itself is owned by
          # uid 1000. `z` only adjusts the mountpoint root -- the subtree is
          # left alone (the *arr stack reconciles /mnt/media recursively via
          # the manual chgrp documented in profile-nas).
          systemd.tmpfiles.rules = [
            "z /mnt/config 0755 root root - -"
            "z /mnt/data   0755 root root - -"
            "z /mnt/media  2775 root media - -"
          ];

          # --- Plex: migrate FCOS state ---
          # lsio container's /config volume root was /mnt/config/plex. Plex's
          # data lives at Library/Application Support/Plex Media Server/ inside
          # it. NixOS plex looks at $PLEX_DATADIR/Plex Media Server/, so bind
          # dataDir to the FCOS parent of "Plex Media Server".
          fileSystems."/var/lib/plex" = {
            device = "/mnt/config/plex/Library/Application Support";
            fsType = "none";
            options = [
              "bind"
              "nofail"
            ];
          };
          # Container-media-path shim. library.db section_locations reference
          # /data/{movies,tv,music,audiobooks,videos}. Remove this bind after
          # the library locations are remapped via Plex UI to /mnt/media/*.
          fileSystems."/data" = {
            device = "/mnt/media";
            fsType = "none";
            options = [
              "bind"
              "nofail"
            ];
          };
          systemd.services.plex.unitConfig.RequiresMountsFor = [
            "/var/lib/plex"
            "/data"
          ];

          swapDevices = [
            { device = "/dev/disk/by-uuid/ce0ee5b6-6ea3-4447-8540-7a52f4887441"; }
          ];

          # --- Intel hardware ---
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

          # UHD 605 (Gemini Lake, Gen 9.5). VA-API via the iHD driver is the
          # supported transcoding path for Jellyfin on this CPU class --
          # oneVPL/QSV requires Tiger Lake+ and won't load here. Ship the i965
          # fallback too in case iHD fails to probe a specific codec.
          hardware.graphics = {
            enable = true;
            extraPackages = with pkgs; [
              intel-media-driver
              intel-vaapi-driver
            ];
          };

          # vainfo confirms the VA-API stack; intel_gpu_top shows live
          # per-engine GPU utilization, which is the definitive way to tell
          # whether Jellyfin transcodes are actually hitting the hardware.
          environment.systemPackages = with pkgs; [
            libva-utils
            intel-gpu-tools
          ];
        }
      )
    ];
  };
}
