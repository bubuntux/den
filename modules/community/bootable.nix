{
  com.bootable.nixos = {
    boot.loader = {
      timeout = 3;
      systemd-boot = {
        enable = true;
        editor = false;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
