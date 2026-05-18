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
          ...
        }:
        {
          networking.hostName = "appa";
          system.stateVersion = "25.11";

          # 4-core J5040 with limited RAM; keep build parallelism conservative
          # so Go-heavy builds (caddy + plugins) don't trigger OOM/kernel oops.
          nix.settings = {
            max-jobs = 1;
            cores = 2;
          };

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

          # --- Service-state bind-mounts ---
          # Native NixOS services pointed at their FCOS-era state on
          # /mnt/config so libraries, watched-state, plugins and configs
          # survive the migration. nofail keeps the box bootable if a bind
          # source is missing; RequiresMountsFor on each service unit
          # prevents start-with-empty-state races.
          #
          # FCOS layout was lsio-container-style: /mnt/config/<svc>/ was the
          # container's /config volume root, so the mapping isn't always
          # one-to-one with the NixOS module defaults.

          # Jellyfin: lsio container's /config volume root was
          # /mnt/config/jellyfin/config (yes, nested), with cache and log as
          # separate sibling dirs at the top level.
          fileSystems."/var/lib/jellyfin" = {
            device = "/mnt/config/jellyfin/config";
            fsType = "none";
            options = [
              "bind"
              "nofail"
            ];
          };
          fileSystems."/var/cache/jellyfin" = {
            device = "/mnt/config/jellyfin/cache";
            fsType = "none";
            options = [
              "bind"
              "nofail"
            ];
          };
          fileSystems."/var/log/jellyfin" = {
            device = "/mnt/config/jellyfin/log";
            fsType = "none";
            options = [
              "bind"
              "nofail"
            ];
          };
          systemd.services.jellyfin.unitConfig.RequiresMountsFor = [
            "/var/lib/jellyfin"
            "/var/cache/jellyfin"
            "/var/log/jellyfin"
          ];

          swapDevices = [
            { device = "/dev/disk/by-uuid/ce0ee5b6-6ea3-4447-8540-7a52f4887441"; }
          ];

          # --- Intel hardware ---
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
          hardware.graphics.enable = true; # Intel UHD 605 for VA-API (Jellyfin transcoding)
        }
      )
    ];
  };
}
