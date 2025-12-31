{ pkgs, ... }:
{
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
  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    enable = true;
    # sway.enable=true;
    gtk.enable = true;
  };
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };
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
}
