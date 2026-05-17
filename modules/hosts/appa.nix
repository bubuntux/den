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
          boot.initrd.kernelModules = [ "dm-snapshot" ];
          # dm-raid + raid1 are needed to assemble the existing LVM RAID1
          # mirrors (config, data LVs in VG `nas`). Root is on sda so these
          # load after init, not in initrd.
          boot.kernelModules = [
            "kvm-intel"
            "dm-raid"
            "raid1"
          ];
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
