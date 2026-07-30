{ self, ... }:
{
  flake.modules.nixos.login-lightdm =
    { config, lib, ... }:
    let
      cfg = config.den.desktop;
    in
    {
      key = "den:nixos.login-lightdm";
      imports = [ self.modules.nixos.desktop-options ];

      config = lib.mkIf (cfg.loginManager == "lightdm") {
        # LightDM never moved to the services.displayManager.* namespace, so it
        # still lives under services.xserver and needs an X server even when
        # every installed session is Wayland-only.
        services.xserver.enable = true;
        services.xserver.displayManager.lightdm.enable = true;
        services.xserver.displayManager.lightdm.greeters.gtk.enable = true;

        # LightDM honours services.displayManager.{defaultSession,autoLogin}.
      };
    };
}
