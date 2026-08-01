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
