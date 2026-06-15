{
  inputs,
  ...
}:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.nixosModules.dell-precision-5680 =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      nvidiaPackage = config.hardware.nvidia.package;
    in
    {
      # OV02C10 (IPU6) webcam: the mainline intel_skl_int3472 driver only gained
      # handling for this sensor's "GPIO type 0x02 (strobe)" power GPIO after 6.18,
      # so on 6.18 the sensor is never powered up (int3472 aborts, csi2 frame-sync
      # errors, isys stream -22). Kernel 7.0.x carries the upstream fix.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # Mainline libcamera Simple-pipeline + SoftISP camera stack. This replaces the
      # proprietary ipu6-camera-hal / v4l2-relayd / icamerasrc path (hardware.ipu6),
      # whose out-of-tree PSYS module does not build on 7.x. nixpkgs' libcamera 0.7
      # builds simple+softisp by default and PipeWire is already linked against
      # libcamera, so we only need device access and to hide the raw ISYS nodes.
      services.udev.extraRules = ''
        # SoftISP buffer allocation from the user session
        KERNEL=="system", SUBSYSTEM=="dma_heap", TAG+="uaccess"
        # Let user-session PipeWire/libcamera open the IPU6 ISYS media + capture nodes
        SUBSYSTEM=="media",       DRIVERS=="intel-ipu6", TAG+="uaccess", GROUP="video", MODE="0660"
        SUBSYSTEM=="video4linux", DRIVERS=="intel-ipu6", TAG+="uaccess", GROUP="video", MODE="0660"
      '';

      # Hide the raw Bayer ISYS v4l2 nodes so apps pick the libcamera-processed camera.
      services.pipewire.wireplumber.extraConfig."51-ipu6-disable-raw-v4l2" = {
        "monitor.v4l2.rules" = [
          {
            matches = [ { "device.product.name" = "ipu6"; } ];
            actions."update-props"."device.disabled" = true;
          }
        ];
      };

      environment.systemPackages = [
        pkgs.libcamera # `cam` for enumeration/capture testing
        pkgs.libcamera-qcam # `qcam` live preview
      ];

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

        graphics.enable = lib.mkDefault true;

        # CDI generation for the NVIDIA discrete GPU. Lives here (not in the
        # podman feature) because the toolkit asserts that nvidia drivers are
        # actually present -- enabling it unconditionally on every podman host
        # breaks any non-NVIDIA host (e.g. appa, which only has an Intel iGPU).
        # The QEMU vmVariant has no GPU to passthrough, so the same assertion
        # would trip there; disable it via the vmVariant override below.
        nvidia-container-toolkit.enable = lib.mkDefault true;

        nvidia = {
          open = lib.mkOverride 990 (nvidiaPackage ? open && nvidiaPackage ? firmware);
          modesetting.enable = lib.mkDefault true;
          nvidiaSettings = lib.mkDefault true;

          powerManagement = {
            enable = lib.mkDefault true;
            finegrained = lib.mkDefault true;
          };

          prime = {
            offload = {
              enable = lib.mkDefault true;
              enableOffloadCmd = lib.mkDefault true;
            };
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

      # No real GPU inside QEMU, so the nvidia-container-toolkit assertion
      # ("requires nvidia drivers") fires when the host's vmVariant is
      # evaluated as part of `nix flake check`. Force-off in the vmVariant.
      virtualisation.vmVariant.hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    };
}
