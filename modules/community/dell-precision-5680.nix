{ lib, ... }:
{

  com.dell-precision-5680 = {
    nixos = {

      hardware = {

        # Webcam
        ipu6 = {
          enable = lib.mkDefault true;
          platform = lib.mkDefault "ipu6ep";
        };

        nvidia.prime = {
          intelBusId = lib.mkDefault "PCI:00:02:0";
          nvidiaBusId = lib.mkDefault "PCI:01:00:0";
        };

      };

      services = {
        hardware.bolt.enable = lib.mkDefault true; # use thunderbolt
        fwupd.enable = lib.mkDefault true; # update firmware
        pcscd.enable = lib.mkDefault true; # card reader
        thermald.enable = lib.mkDefault true; # fans
      };

    };

  };

}
