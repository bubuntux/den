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
    modules = [ self.modules.nixos.appa ];
  };

  # Host identity and operating policy. Hardware, storage, networking and the
  # Plex migration are separate fragments of this same module name -- each gets
  # its own `key`, and flake.modules merges them into one imports list.
  #
  # Everything here argues from one premise: a headless box that can sit
  # unreachable for weeks, on 4 slow cores and limited RAM.
  flake.modules.nixos.appa =
    { lib, ... }:
    {
      key = "den:nixos.appa#host";
      imports = with self.modules.nixos; [
        profile-nas
        inputs.nixos-hardware.nixosModules.common-cpu-intel
        inputs.nixos-hardware.nixosModules.common-pc-ssd
      ];

      networking.hostName = "appa";
      system.stateVersion = "25.11";

      # Run unattended weekly: Sunday at 03:00 build the new generation and
      # apply it live -- operation=switch overrides the shared default's
      # "boot", so userspace and security updates land every week without a
      # reboot. Only a new kernel/initrd pends: it is staged as the boot
      # default and takes effect on the next deliberate, attended reboot.
      # Crucially, never auto-reboot.
      #
      # 2026-06-07 incident: the weekly upgrade bumped the kernel
      # (6.18.33 -> 6.18.34) and, with allowReboot=true, auto-rebooted at
      # 03:19 while the operator was on vacation. This ASRock J5040-ITX
      # (BIOS P1.60, 2020) hung on the warm reboot -- a known Gemini Lake
      # firmware quirk -- before POST, so it never reached the kernel. The
      # 10-min reboot watchdog did not recover it, and with no one to
      # power-cycle, the NAS sat dark for ~37h until a manual cold boot
      # (which booted the *identical* generation cleanly, proving the build
      # was fine and the reboot transition was at fault). See the reboot=pci
      # kernel param in hardware.nix for the firmware-hang fix.
      #
      # Policy: a headless box that can sit unreachable for weeks must never
      # gamble an unattended reboot on firmware that may not come back.
      system.autoUpgrade = {
        dates = "Sun *-*-* 03:00:00";
        operation = "switch";
        allowReboot = false;
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
    };
}
