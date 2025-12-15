{
  com.bluetooth = {
    nixos = {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      services.blueman.enable = true;
    };
    homeManager = {
      services.blueman-applet.enable = true;
    };
  };
}
