{
  inputs,
  lib,
  config,
  com,
  ...
}:
let
  nvidiaPackage = config.hardware.nvidia.package;
in
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  com.dell-precision-5680.nixos = {
    imports = [
      com.bluetooth.nixos
      com.all-firmware.nixos
      inputs.nixos-hardware.nixosModules.common-hidpi
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      inputs.nixos-hardware.nixosModules.common-pc-laptop
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    ];

    hardware = {
      # Webcam
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
          intelBusId = lib.mkDefault "PCI:00:02:0";
          nvidiaBusId = lib.mkDefault "PCI:01:00:0";
        };
      };
    };

    services = {
      fwupd.enable = lib.mkDefault true; # update firmware
      hardware.bolt.enable = lib.mkDefault true; # use thunderbolt
      pcscd.enable = lib.mkDefault true; # card reader
      thermald.enable = lib.mkDefault true; # fans
    };

  };
}
