{ self, ... }:
{
  flake.modules.nixos.profile-wife = {
    key = "den:nixos.profile-wife";
    imports = with self.modules.nixos; [
      user-shari
      bundle-desktop
      firefox
      openssh
    ];

    # GNOME on GDM, logging straight in -- this is a single-user machine that
    # nobody wants to type a password at.
    den.desktop = {
      environments = [ "gnome" ];
      loginManager = "gdm";
      users.shari = "gnome";
    };
    services.displayManager.defaultSession = "gnome";
    services.displayManager.autoLogin = {
      enable = true;
      user = "shari";
    };
  };
}
