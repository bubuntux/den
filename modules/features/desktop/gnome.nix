{
  flake.nixosModules.gnome =
    { pkgs, ... }:
    {
      # Enable the GNOME Desktop Environment.
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;
      services.gnome.core-developer-tools.enable = false;

      environment.gnome.excludePackages = with pkgs; [
        epiphany # web browser
        gnome-tour
        gnome-user-docs
      ];

      # Enable the X11 windowing system.
      services.xserver = {
        enable = true;
        excludePackages = with pkgs; [ xterm ];
      };

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "us";
        variant = "";
      };

      # Enable automatic login for the user.
      services.displayManager.autoLogin.enable = true;
      services.displayManager.autoLogin.user = "dona"; # TODO

      # Enable networking TODO
      networking.networkmanager.enable = true;

      # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
      systemd.services."getty@tty1".enable = false;
      systemd.services."autovt@tty1".enable = false;

    };
}
