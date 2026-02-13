{
  flake.nixosModules.plymouth = {
    # Systemd in initrd is required for modern plymouth integration
    boot.initrd.systemd.enable = true;

    boot.plymouth = {
      enable = true;
      # bgrt uses the OEM logo, but doesn't work well in VMs.
      # spinner is a clean, universal default.
      theme = "spinner";
    };

    # Required for the splash screen to show up in QEMU VMs
    boot.initrd.kernelModules = [ "virtio_gpu" ];

    # Ensure quiet boot so plymouth looks good
    boot.kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "vt.global_cursor_default=0"
      "console=tty1"
    ];
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
  };
}
