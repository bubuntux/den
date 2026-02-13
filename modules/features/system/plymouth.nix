{
  flake.nixosModules.plymouth = {
    boot.plymouth = {
      enable = true;
      # bgrt is the default theme that uses the OEM logo (Dell logo in this case)
      # keeping it simple and "native" looking.
      theme = "bgrt";
    };

    # Ensure quiet boot so plymouth looks good
    boot.kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
  };
}
