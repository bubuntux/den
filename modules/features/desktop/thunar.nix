_: {
  # Thunar is a *session's* file manager, not the machine's: only a session that
  # lacks one of its own asks for it (Sway does, GNOME has nautilus). So it is
  # imported by session/sway/ rather than by bundle-desktop, and split in two --
  # with no `home-manager.sharedModules` here, since pushing the folder
  # association at every user on the host is exactly what would hand a GNOME
  # user Sway's file manager.
  flake.modules = {
    # System half: installing a program cannot be done per user.
    #
    # Gated because `imports` ignores the `mkIf` a session wraps its config in,
    # and bundle-desktop imports every session unconditionally -- without this,
    # importing thunar from the Sway session would install it on GNOME-only
    # hosts too. programs.sway.enable is the session's own switch, so this
    # follows it exactly and needs no option of its own.
    nixos.thunar =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        key = "den:nixos.thunar";
        config = lib.mkIf config.programs.sway.enable {
          services.gvfs.enable = true; # Mount, trash, and other functionalities
          services.tumbler.enable = true; # Thumbnail support for images
          programs.thunar = {
            enable = true;
            plugins = with pkgs; [
              thunar-media-tags-plugin
              thunar-archive-plugin
              thunar-volman
            ];
          };
        };
      };

    # User half -- imported by the session that wants thunar opening folders,
    # which attaches it per user through den.desktop.users.
    homeManager.thunar = {
      key = "den:homeManager.thunar";
      xdg.mimeApps.defaultApplications = {
        "inode/directory" = "thunar.desktop";
        "x-scheme-handler/file" = "thunar.desktop";
      };
    };
  };
}
