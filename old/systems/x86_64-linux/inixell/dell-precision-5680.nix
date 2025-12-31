{
  inputs,
  lib,
  config,
  ...
}:
let
  nvidiaPackage = config.hardware.nvidia.package;
in
{
  imports = [
    inputs.hardware.nixosModules.common-hidpi
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-nvidia
  ];

  hardware = {
    # Audio
    enableRedistributableFirmware = lib.mkDefault true;
    enableAllFirmware = lib.mkDefault true; # <--- Add this line

    # Webcam
    ipu6 = {
      enable = lib.mkDefault true;
      platform = lib.mkDefault "ipu6ep";
    };

    bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
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

  # Add this block to ensure sof-firmware is loaded
  boot.initrd.kernelModules = [ "snd-sof-pci" ]; # <--- Add this line
}
