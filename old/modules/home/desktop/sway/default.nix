{ pkgs, ... }:
let
  wallpaper = builtins.fetchurl {
    url = "https://github.com/NixOS/nixos-artwork/blob/63f68a917f4e8586c5d35e050cdaf1309832272d/wallpapers/nix-wallpaper-binary-black_8k.png?raw=true";
    sha256 = "331120bf35a676a31e23919e23a1f3722eb277988be383435f22903aec3e7cb6";
  };
in
{

  xdg.configFile."sway/config.d".source = ./config.d;

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;
    wrapperFeatures.base = true;
    wrapperFeatures.gtk = true;

    extraOptions = [ "--unsupported-gpu" ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
      export NIXOS_OZONE_WL=1
      export WLR_NO_HARDWARE_CURSORS=1;
    '';

    config = null;
    extraConfig = "
    output * bg ${wallpaper} fill
    include '\${XDG_CONFIG_HOME:-$HOME/.config}/sway/config.d/*.conf /usr/share/sway/config.d/*.conf /etc/sway/config.d/*.conf'";
  };

  home.packages = with pkgs; [
    # xdg-utils
    # glib
    # gtk3.out
    #
    # gnome-themes-extra
    # #gnome3.adwaita-icon-theme # default gnome cursors
    # adwaita-icon-theme
    # hicolor-icon-theme
    # tango-icon-theme
    #
    # desktop-file-utils
    # shared-mime-info # for update-mime-database
    # polkit_gnome
    # xdg-user-dirs
    #
    # light
    # imv
    # xfce.thunar
    #
    #rofi-wayland
    clipman

    mako # notification system developed by swaywm maintainer
    waybar
    slurp # scrennshare?

    warpd

    swaylock
    swayidle
    sway-contrib.grimshot
    wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
    wdisplays # tool to configure displays
  ];

  services.mako = {
    enable = true;
    settings.default-timeout = 5000;
  };

  programs.rofi = {
    enable = true;
    theme = "Arc-Dark";
    package = pkgs.rofi;
    #terminal = "${pkgs.foot}/bin/foot";
  };

  xdg = {
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      # config.common.default = "*";
      config = {
        common.default = "gtk";
        sway = {
          default = [ "gtk" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        };
      };
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
    };
  };

  targets.genericLinux.enable = true;
}
