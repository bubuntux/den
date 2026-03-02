{
  self,
  ...
}:
{
  # Home Manager module for GTK/Qt theming
  flake.homeModules.theme =
    { pkgs, ... }:
    {
      # GTK theme
      gtk = {
        enable = true;
        cursorTheme.name = "Adwaita";
        theme = {
          package = pkgs.gnome-themes-extra;
          name = "Adwaita-dark";
        };
        iconTheme = {
          package = pkgs.adwaita-icon-theme;
          name = "Adwaita";
        };
        gtk4.extraConfig = {
          gtk-application-prefer-dark-theme = true;
        };
      };

      # Cursor theme
      home.pointerCursor = {
        name = "Vanilla-DMZ";
        package = pkgs.vanilla-dmz;
        enable = true;
        gtk.enable = true;
      };

      # dconf settings for dark mode
      dconf = {
        enable = true;
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };
        };
      };

      # Qt theme
      qt = {
        enable = true;
        platformTheme = {
          name = "gtk";
        };
        style = {
          package = pkgs.adwaita-qt;
          name = "adwaita-dark";
        };
      };
    };

  # NixOS module that includes theme home module
  flake.nixosModules.theme =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.theme ];
    };
}
