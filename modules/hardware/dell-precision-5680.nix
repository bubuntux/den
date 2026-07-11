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
      imports = [
        inputs.nixos-hardware.nixosModules.common-hidpi
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        inputs.nixos-hardware.nixosModules.common-pc-laptop
        inputs.nixos-hardware.nixosModules.common-cpu-intel
        inputs.nixos-hardware.nixosModules.common-gpu-nvidia
      ];

      # The built-in IPU6/MIPI camera (ov02c10 sensor) only exposes raw Bayer
      # V4L2 nodes browsers can't use, and its 32 ISYS capture nodes make
      # Firefox's camera enumeration take ~50s -- so no camera ever appears in
      # time (Chrome tolerates it). Its libcamera SoftISP path also crashes, so
      # the built-in cam is unused: DroidCam / the Logitech BRIO are the webcams.
      # Blacklist the whole IPU6 stack so those dead /dev/video* nodes are never
      # created. (Takes effect on reboot -- the modules are loaded at boot.)
      boot.blacklistedKernelModules = [
        "intel_ipu6"
        "intel_ipu6_isys"
        "ipu_bridge"
        "ov02c10"
      ];

      # Every display on the 5680 is driven by the Intel iGPU (PCI 00:02.0); the
      # NVIDIA dGPU is PRIME-offload only. Left alone, wlroots picks NVIDIA as its
      # primary renderer and does a cross-GPU copy every frame -- which made
      # Firefox screen-share stream a single frozen frame (one frame, then stuck
      # until a pause/resume). Pin wlroots to the Intel GPU instead.
      #
      # WLR_DRM_DEVICES is a COLON-separated list, so the /dev/dri/by-path name
      # (which is full of colons) gets split into garbage; and /dev/dri/cardN
      # numbering isn't stable across boots. So expose a stable, colon-free
      # symlink to the Intel card by its fixed PCI slot and point wlroots at that.
      # PRIME offload (nvidia-offload / __NV_PRIME_RENDER_OFFLOAD) is unaffected
      # -- wlroots never opens the dGPU, so it can also idle/suspend.
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", KERNEL=="card[0-9]*", KERNELS=="0000:00:02.0", SYMLINK+="dri/intel"
      '';
      environment.sessionVariables.WLR_DRM_DEVICES = "/dev/dri/intel";

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

          # finegrained (RTD3 dynamic power management, NVreg_DynamicPowerManagement=0x02)
          # is off: it made nvidia_uvm's boot-time init block ~10s on an RTD3 power
          # transition. Because the kernel serializes module insertion, that stall
          # queued audio/sensors/camera behind it and gated sysinit.target -- ~15s of
          # the boot. `enable` stays on: it only preserves VRAM across system
          # suspend/resume (no boot cost) and PRIME offload is unaffected either way.
          # The dGPU no longer auto-suspends to D3cold when idle (small idle-power
          # cost, already largely negated by waybar's periodic nvidia-smi polling).
          powerManagement = {
            enable = lib.mkDefault true;
            finegrained = lib.mkDefault false;
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
