{
  inputs,
  ...
}:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.modules.nixos.dell-precision-5690 =
    {
      lib,
      ...
    }:
    {
      key = "den:nixos.dell-precision-5690";
      imports = [
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        inputs.nixos-hardware.nixosModules.common-pc-laptop
        inputs.nixos-hardware.nixosModules.common-gpu-nvidia
        "${inputs.nixos-hardware}/common/cpu/intel/meteor-lake"
        "${inputs.nixos-hardware}/common/gpu/nvidia/ada-lovelace"
      ];

      # All displays hang off the Intel iGPU; the dGPU is PRIME-offload only.
      # Unpinned, wlroots picks NVIDIA and copies across GPUs every frame, which
      # froze Firefox screen-share on a single frame. WLR_DRM_DEVICES is
      # colon-separated so /dev/dri/by-path names split into garbage, and cardN
      # is not stable across boots -- hence a colon-free symlink by PCI slot.
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", KERNEL=="card[0-9]*", KERNELS=="0000:00:02.0", SYMLINK+="dri/intel"
      '';
      environment.sessionVariables.WLR_DRM_DEVICES = "/dev/dri/intel";

      hardware = {
        enableRedistributableFirmware = lib.mkDefault true;
        enableAllFirmware = lib.mkDefault true;

        graphics.enable = lib.mkDefault true;

        cpu.intel.npu.enable = lib.mkDefault true;

        # CDI generation for the NVIDIA discrete GPU. Lives here (not in the
        # podman feature) because the toolkit asserts that nvidia drivers are
        # actually present -- enabling it unconditionally on every podman host
        # breaks any non-NVIDIA host (e.g. appa, which only has an Intel iGPU).
        # The QEMU vmVariant has no GPU to passthrough, so the same assertion
        # would trip there; disable it via the vmVariant override below.
        nvidia-container-toolkit.enable = lib.mkDefault true;

        nvidia = {
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

      # No real GPU inside QEMU, so the nvidia-container-toolkit assertion
      # ("requires nvidia drivers") fires when the host's vmVariant is
      # evaluated as part of `nix flake check`. Force-off in the vmVariant.
      virtualisation.vmVariant.hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    };
}
