{ self, ... }:
{
  # A session's file manager, not the machine's: imported by
  # session/wayland.nix, since GNOME has nautilus.
  flake.modules = {
    # Gated on sessionAnchors rather than one compositor, because `imports`
    # escapes a session's mkIf. See CLAUDE.md.
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

    # One `<desktop>-mimeapps.list` per bare session, which XDG reads ahead of
    # the shared list -- so folders open in thunar under Sway and nautilus under
    # GNOME out of one home. See CLAUDE.md.
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
