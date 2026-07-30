{ ... }:
{
  # LVM array, filesystems and the disk-level tuning that goes with them.
  # UUIDs are stable -- these drives are NOT reformatted.
  flake.modules.nixos.appa = {
    key = "den:nixos.appa#storage";

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

    # LVM support (systemd initrd handles dm modules automatically)
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

    swapDevices = [
      { device = "/dev/disk/by-uuid/ce0ee5b6-6ea3-4447-8540-7a52f4887441"; }
    ];
  };
}
