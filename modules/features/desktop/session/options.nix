_: {
  # Session schema at *user* scope; `den.desktop` is the machine's view.
  flake.modules.homeManager.session-options =
    { pkgs, lib, ... }:
    {
      key = "den:homeManager.session-options";

      options.den.session = {
        anchors = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            sway = "wayland-session@sway.target";
          };
          description = ''
            Desktop id -> the systemd *user* unit that means "that session is
            running". Companion services hang their WantedBy/PartOf on these
            rather than on graphical-session.target, which every desktop starts.

            The key is the id the session announces in XDG_CURRENT_DESKTOP, and
            names per-desktop files such as `<id>-mimeapps.list`; the value is
            the unit. A module belonging to one session must not read this --
            it would start under the user's other desktops too.

            See CLAUDE.md, "Desktop Environments and Login Managers".
          '';
        };

        activeBar = lib.mkOption {
          type = lib.types.str;
          default = "waybar";
          description = ''
            Which installed bar this session starts. A renderer hangs its unit's
            WantedBy on being the match, so the others are present but never
            pulled in by the session.

            The host's view is `den.desktop.bar`; Home Manager cannot read NixOS
            config, so session-wayland states both. Not an enum on purpose --
            the set of names lives with the host option.
          '';
        };

        bar = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                modules = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  example = [ "sway/workspaces" ];
                  description = ''
                    The compositor's own Waybar modules, placed at the head of
                    modules-left. Everything else on the bar is shared.
                  '';
                };

                settings = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                  description = ''
                    Waybar configuration for those modules, merged over the
                    shared bar; a key defined in both wins here.
                  '';
                };
              };
            }
          );
          default = { };
          description = ''
            Desktop id -> the part of the bar only that compositor understands,
            keyed like `anchors` above. Each entry becomes a config and a
            systemd user unit of its own, started by that session's anchor.

            One bar cannot serve two compositors: Waybar drops a module it
            cannot create and carries on with a gap. See CLAUDE.md, "One bar
            per session".
          '';
        };

        wallpaper = lib.mkOption {
          type = lib.types.path;
          default = pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath;
          defaultText = lib.literalExpression "pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath";
          description = ''
            Image shown behind the session and on the lock screen, so the two
            cannot drift apart: the session sets the background, session/
            wayland.nix configures swaylock once for all of them.
          '';
        };
      };
    };
}
