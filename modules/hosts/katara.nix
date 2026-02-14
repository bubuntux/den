{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.katara = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      profile-laptop
      profile-wife
      firefox
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
      (
        {
          config,
          lib,
          modulesPath,
          ...
        }:
        {
          # TODO
          networking.hostName = "katara";
          system.stateVersion = "25.11";

          # Enable firmware updates
          services.fwupd.enable = true;
          # Enable fingerprint reader
          services.fprintd.enable = true;

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
        }
      )
    ];
  };
}
