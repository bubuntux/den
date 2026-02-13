{
  flake.nixosModules.plymouth = {
    # Systemd in initrd is required for modern plymouth integration
    boot.initrd.systemd.enable = true;

    boot.plymouth = {
      enable = true;
      # bgrt is the default theme that uses the OEM logo (Dell logo in this case)
      theme = "bgrt";
    };

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
    ];
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
  };
}