_: {
  # Session schema at *user* scope. `den.desktop` (features/desktop/options.nix)
  # is the machine's view of the desktops -- which are installed, which greeter
  # presents them. This is what a session's companion programs need in order to
  # attach themselves to the right session inside one home.
  flake.modules.homeManager.session-options =
    { pkgs, lib, ... }:
    {
      key = "den:homeManager.session-options";

      options.den.session = {
        anchors = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            sway = "sway-session.target";
          };
          description = ''
            Desktop id -> the systemd *user* unit that means "that session is
            running". Companion services -- bar, idle handling, output
            management, colour temperature -- hang their WantedBy/PartOf on
            these instead of on graphical-session.target.

            Keyed by desktop id, not a bare list, because the key is worth as
            much as the value: it is what a session announces in
            XDG_CURRENT_DESKTOP, so a companion that needs per-desktop *files*
            rather than per-desktop units can name them. features/desktop/
            thunar.nix writes `<id>-mimeapps.list` that way, which XDG reads
            ahead of the shared mimeapps.list.

            The distinction is the whole point. graphical-session.target is
            started by *every* desktop, GNOME included, so a companion bound to
            it follows the user into any session: on katara that put Waybar over
            mutter, a kanshi against mutter's own output handling and swayidle
            locking a GNOME session with swaylock, all for a user whose only
            crime was having Sway config in his home.

            Contributed by each session module. Every user on the host receives
            every installed desktop's config, so the set here is normally all of
            the bare sessions, and the shared companions come up in whichever one
            the user logged into. Not every value is a `.target`: Sway's is Home
            Manager's generated sway-session.target, while niri ships no session
            target and its anchor would be niri.service.

            A module belonging to ONE session must NOT read this -- with two
            desktops in a home it would start that session's bar under the other
            one too. Those bind to their own anchor by name; see
            session/sway/waybar.nix.

            The system-level counterpart is `den.desktop.sessionAnchors`.
          '';
        };

        wallpaper = lib.mkOption {
          type = lib.types.path;
          default = pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath;
          defaultText = lib.literalExpression "pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath";
          description = ''
            Image shown behind the session and on the lock screen. Read by both,
            so a session and its locker cannot drift apart: the desktop
            background is the session's business (Sway sets `output "*" bg`)
            while swaylock is configured once for every session in
            session/wayland.nix.

            nixos-artwork is archived upstream, but nixpkgs still ships these
            wallpapers; gnomeFilePath points straight at the PNG in the store,
            so there is no eval-time fetch.
          '';
        };
      };
    };
}
