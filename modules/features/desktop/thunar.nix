{ self, ... }:
{
  # Thunar is a *session's* file manager, not the machine's: only a session that
  # lacks one of its own asks for it (Sway does, GNOME has nautilus). So it is
  # imported by session/wayland.nix rather than by bundle-desktop.
  flake.modules = {
    # System half: installing a program cannot be done per user.
    #
    # Gated because `imports` ignores the `mkIf` a session wraps its config in,
    # and bundle-desktop imports every session unconditionally -- without this,
    # importing thunar from a session would install it on GNOME-only hosts too.
    # den.desktop.sessionAnchors is non-empty exactly when some installed session
    # ships no shell of its own, which is the set of sessions that want a file
    # manager. It used to follow programs.sway.enable, which named one
    # compositor and would have gone stale the moment a second one arrived.
    nixos.thunar =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        key = "den:nixos.thunar";
        imports = [ self.modules.nixos.desktop-options ];
        config = lib.mkIf (config.den.desktop.sessionAnchors != { }) {
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

    # User half -- imported by session/wayland.nix.
    #
    # Written as one `<desktop>-mimeapps.list` per bare session rather than into
    # the home's shared mimeapps.list, because every user carries every installed
    # desktop's config now: a plain default would make folders open in thunar
    # inside GNOME too, where nautilus is right there. The XDG mime-apps spec has
    # the answer -- $XDG_CONFIG_HOME/<desktop>-mimeapps.list is consulted before
    # mimeapps.list, once per entry in XDG_CURRENT_DESKTOP -- so the association
    # simply is not visible outside the sessions that asked for it. Sway
    # announces "sway;wlroots", niri "niri"; the id is the key of
    # den.session.anchors.
    homeManager.thunar =
      { config, lib, ... }:
      {
        key = "den:homeManager.thunar";
        imports = [ self.modules.homeManager.session-options ];

        xdg.configFile = lib.mapAttrs' (
          desktop: _:
          lib.nameValuePair "${desktop}-mimeapps.list" {
            text = lib.generators.toINI { } {
              "Default Applications" = {
                "inode/directory" = "thunar.desktop";
                "x-scheme-handler/file" = "thunar.desktop";
              };
            };
          }
        ) config.den.session.anchors;
      };
  };
}
