{ self, ... }:
{
  flake.modules.nixos.login-gdm =
    { config, lib, ... }:
    let
      cfg = config.den.desktop;
      dm = config.services.displayManager;
    in
    {
      key = "den:nixos.login-gdm";
      imports = [ self.modules.nixos.desktop-options ];

      config = lib.mkIf (cfg.loginManager == "gdm") {
        services.displayManager.gdm.enable = true;

        # GDM honours services.displayManager.{defaultSession,autoLogin}
        # directly, so nothing to translate here.
        #
        # The tty1 units have to go, or GDM's autologin session races getty for
        # the console and the session dies.
        # https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
        systemd.services."getty@tty1".enable = lib.mkIf dm.autoLogin.enable false;
        systemd.services."autovt@tty1".enable = lib.mkIf dm.autoLogin.enable false;
      };
    };
}
