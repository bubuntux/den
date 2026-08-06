{ ... }:
{
  flake.modules.nixos.zuko =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      key = "den:nixos.zuko#hardware";
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      # Keep the network off the boot critical path: NetworkManager-wait-online
      # sat on it, adding ~4s. Nothing on zuko needs the network before the
      # graphical session -- ntpd-rs / geoclue simply retry once the link is up.
      systemd.services.NetworkManager-wait-online.enable = false;

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usbhid"
        "rtsx_pci_sdmmc"
      ];
      boot.initrd.kernelModules = [ ];
      # Preload the FAT/NLS modules the vfat /boot (ESP) mount needs. Without
      # this the kernel auto-loads them mid-mount, and that request stalls
      # ~11s behind nvidia_uvm's slow init (kernel serializes module loading),
      # showing as a "A start job is running for /boot" hang every boot.
      boot.kernelModules = [
        "kvm-intel"
        "vfat"
        "nls_cp437"
        "nls_iso8859-1"
      ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/1981375b-540a-4a5a-8c10-9f044b4ea6c8";
        fsType = "ext4";
      };

      boot.initrd.luks.devices = {
        "luks-3a9aee91-3370-453d-b32c-c28235011fd8" = {
          device = "/dev/disk/by-uuid/3a9aee91-3370-453d-b32c-c28235011fd8";
          allowDiscards = true;
        };
        "luks-cd021106-a3fc-44f9-b291-2bf9eb1ed614".device =
          "/dev/disk/by-uuid/cd021106-a3fc-44f9-b291-2bf9eb1ed614";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/29B5-9AC3";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [
        { device = "/dev/disk/by-uuid/571a575d-451d-4706-b5fa-c0cf596bff9d"; }
      ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.keyboard.zsa.enable = true;
      hardware.intel-gpu-tools.enable = true;
    };
}
