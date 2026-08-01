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

      # Weekly switch, never an unattended reboot: a new kernel is staged as the
      # boot default and waits for a deliberate, attended one.
      #
      # allowReboot=true cost 37h of downtime on 2026-06-07 -- the box rebooted
      # itself at 03:19 during a vacation and hung before POST on a Gemini Lake
      # firmware quirk, which the watchdog cannot recover from. A headless box
      # that can sit unreachable for weeks must not gamble on firmware coming
      # back. See reboot=pci in hardware.nix.
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

      # Half a core reserved for the kernel, journald and sshd. Without it, an
      # Immich backfill plus a qbittorrent recheck plus an *arr scan pin all
      # four cores and the box looks frozen without anything having OOM'd
      # (2026-05-24). 350% = 4 cores minus that headroom.
      systemd.slices.system.sliceConfig.CPUQuota = "350%";

      # geoclue cannot set the timezone on a headless host: timedated's dbus
      # policy only grants it to interactive callers.
      time.timeZone = "America/Chicago";
      services.automatic-timezoned.enable = lib.mkForce false;
      services.geoclue2.enable = lib.mkForce false;
    };
}
