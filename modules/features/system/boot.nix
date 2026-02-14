{
  flake.nixosModules.boot = {
    boot = {
      loader = {
        timeout = 3;
        systemd-boot = {
          enable = true;
          editor = false;
          consoleMode = "max";
          configurationLimit = 15;
        };
        efi.canTouchEfiVariables = true;
      };

      # Systemd in initrd is required for modern plymouth integration
      initrd = {
        systemd.enable = true;
        verbose = false;
      };

      plymouth = {
        enable = true;
        # bgrt is the default theme that uses the OEM logo (Dell logo in this case)
        theme = "bgrt";
      };

      # Ensure quiet boot so plymouth looks good
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        "vt.global_cursor_default=0"
      ];
      consoleLogLevel = 0;
    };
  };
}
