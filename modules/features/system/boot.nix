{
  flake.nixosModules.boot = {
    boot.loader = {
      timeout = 3;
      systemd-boot = {
        enable = true;
        editor = false;
        consoleMode = "max";
        configurationLimit = 15;
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
