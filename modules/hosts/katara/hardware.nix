{ ... }:
{
  flake.modules.nixos.katara =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      key = "den:nixos.katara#hardware";
      # Enable firmware updates
      services.fwupd.enable = true;

      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.extraModulePackages = [ ];

      # The WD19TB's own Realtek hubs -- 5487/5413 are the USB2 halves, 0487/0413
      # the SuperSpeed ones, and all four must be pinned or the pair goes down
      # together. See CLAUDE.md, "The dock on katara" for what a drop costs.
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5487|5413|0487|0413", ATTR{power/control}="on"
      '';

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/1f24fa25-4b1e-4433-a643-0a585c1a5134";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/55CA-E94B";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [
        { device = "/dev/disk/by-uuid/e6ec01aa-d7a0-4623-96fe-a6d9606dd1fc"; }
      ];

      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
