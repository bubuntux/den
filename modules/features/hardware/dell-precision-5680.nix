{
  inputs,
  ...
}:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.nixosModules.dell-precision-5680 =
    { lib, config, ... }:
    let
      nvidiaPackage = config.hardware.nvidia.package;
    in
    {
      imports = [
        inputs.nixos-hardware.nixosModules.common-hidpi
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        inputs.nixos-hardware.nixosModules.common-pc-laptop
        inputs.nixos-hardware.nixosModules.common-cpu-intel
        inputs.nixos-hardware.nixosModules.common-gpu-nvidia
      ];

      hardware = {
        enableRedistributableFirmware = lib.mkDefault true;
        enableAllFirmware = lib.mkDefault true;

        # Webcam (Intel IPU6EP for Raptor Lake)
        ipu6 = {
          enable = lib.mkDefault true;
          platform = lib.mkDefault "ipu6ep";
        };

        graphics.enable = lib.mkDefault true;

        nvidia = {
          open = lib.mkOverride 990 (nvidiaPackage ? open && nvidiaPackage ? firmware);
          modesetting.enable = lib.mkDefault true;
          nvidiaSettings = lib.mkDefault true;

          powerManagement = {
            enable = lib.mkDefault true;
            finegrained = lib.mkDefault true;
          };

          prime = {
            intelBusId = lib.mkDefault "PCI:0:2:0";
            nvidiaBusId = lib.mkDefault "PCI:1:0:0";
          };
        };
      };

      services = {
        fwupd.enable = lib.mkDefault true;
        hardware.bolt.enable = lib.mkDefault true;
        pcscd.enable = lib.mkDefault true;
        thermald.enable = lib.mkDefault true;
      };
    };
}
