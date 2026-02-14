{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.zuko = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      profile-laptop
      dell-precision-5680
      (
        {
          config,
          lib,
          modulesPath,
          ...
        }:
        {
          networking.hostName = "zuko";
          system.stateVersion = "25.11";

          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

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
          boot.kernelModules = [ "kvm-intel" ];
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
        }
      )
    ];
  };
}
