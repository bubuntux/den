{ ... }:
{
  # Intel Pentium Silver J5040 (Gemini Lake) on an ASRock J5040-ITX, BIOS P1.60.
  # Disks and mounts live in storage.nix.
  flake.modules.nixos.appa =
    {
      config,
      lib,
      modulesPath,
      pkgs,
      ...
    }:
    {
      key = "den:nixos.appa#hardware";
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      # sda is /dev/disk/by-id/ata-WDC_WDS500G1R0A-68A4W0_233710800325
      boot.initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];

      boot.kernelModules = [ "kvm-intel" ];

      # em28xx corrupts kernel memory and hangs the box (oopses 2026-08-09 and
      # 2026-10-02); the Hauppauge sticks stay plugged in but unbound.
      boot.blacklistedKernelModules = [
        "em28xx"
        "em28xx_dvb"
        "em28xx_rc"
        "em28xx_v4l"
        "em28xx_alsa"
      ];
      boot.extraModulePackages = [ ];

      # Slab corruption plus silent freezes across kernels points at the DIMM.
      boot.loader.systemd-boot.memtest86.enable = true;

      # em28xx-based tuners load demodulator firmware blobs from
      # linux-firmware at probe time. Without redistributable firmware the
      # driver attaches but every channel scan returns "no signal".
      hardware.enableRedistributableFirmware = true;

      # /dev/dvb adapter nodes default to root:root 0600, which keeps the
      # tvheadend container (running as PUID/PGID 989) from opening the
      # tuner even with --device passthrough. GROUP=video matches the
      # supplementary group the container picks up via --group-add.
      services.udev.extraRules = ''
        SUBSYSTEM=="dvb", GROUP="video", MODE="0660"
      '';

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      # UHD 605 (Gemini Lake, Gen 9.5). VA-API via the iHD driver is the
      # supported transcoding path for Jellyfin on this CPU class --
      # oneVPL/QSV requires Tiger Lake+ and won't load here. Ship the i965
      # fallback too in case iHD fails to probe a specific codec.
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-vaapi-driver
        ];
      };

      # vainfo confirms the VA-API stack; intel_gpu_top shows live
      # per-engine GPU utilization, which is the definitive way to tell
      # whether Jellyfin transcodes are actually hitting the hardware.
      environment.systemPackages = with pkgs; [
        libva-utils
        intel-gpu-tools
      ];

      # --- Headless: disable plymouth, show boot messages ---
      boot.plymouth.enable = lib.mkForce false;
      # reboot=pci forces the CF9h PCI-reset path. The default ACPI/EFI
      # reboot hangs this ASRock J5040-ITX (BIOS P1.60) on warm reboot --
      # the firmware fails to re-POST and the box never comes back (the
      # 2026-06-07 incident documented at system.autoUpgrade in default.nix).
      # CF9h drives a full reset the firmware handles reliably. Validate with
      # one attended `sudo reboot` after deploying; if it still hangs, fall
      # back to reboot=acpi, then reboot=cold.
      boot.kernelParams = lib.mkForce [
        "boot.shell_on_fail"
        "reboot=pci"
      ];
      boot.consoleLogLevel = lib.mkForce 3;
    };
}
