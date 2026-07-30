{ self, ... }:
{
  flake.modules = {
    nixos.gnome =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        key = "den:nixos.gnome";
        imports = [ self.modules.nixos.desktop-options ];

        config = lib.mkIf (lib.elem "gnome" config.den.desktop.environments) {
          # Registers the "gnome" session via
          # services.displayManager.sessionPackages; it does *not* pull in GDM
          # (nixpkgs' gnome module names gdm only inside a nixos-generate-config
          # doc string). Pick the greeter with den.desktop.loginManager.
          services.desktopManager.gnome.enable = true;
          services.gnome.core-developer-tools.enable = false;

          environment.gnome.excludePackages = with pkgs; [
            epiphany # web browser
            gnome-calculator
            gnome-tour
            gnome-user-docs
            yelp # Help
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

          # Deliberately no den.desktop.sessionCommands entry: GNOME's session
          # exec carries environment setup that GDM performs (session mode, dbus
          # activation), so hardcoding a command for greetd's fallback path would
          # be wrong. GNOME stays selectable from any greeter's session list,
          # which reads the real .desktop file.
        };
      };

    # GNOME keeps nearly all user state in GSettings/dconf rather than dotfiles,
    # so this is thin. It exists so den.desktop.users can name "gnome" the way
    # it names "sway", and so GNOME-specific user config has an obvious home.
    homeManager.gnome = {
      key = "den:homeManager.gnome";
      dconf.enable = true;
    };
  };
}
