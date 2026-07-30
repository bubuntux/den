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
        "ahci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
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
        device = "/dev/disk/by-uuid/cb3960d5-892b-4c85-a601-eb2458a6cd0d";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/E362-89D9";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [
        { device = "/dev/disk/by-uuid/b917e6de-c591-42f3-8047-79289917afc4"; }
      ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.keyboard.zsa.enable = true;
      hardware.intel-gpu-tools.enable = true;
    };
}
