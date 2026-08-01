{ self, ... }:
let
  # The environments this repo knows how to install. Adding a desktop is one
  # entry here plus its session file and a bundle-desktop import.
  sessionNames = [
    "sway"
    "gnome"
  ];
in
{
  # Desktop selection surface. Two knobs only -- which environments to install
  # and which login manager presents them -- because everything else already
  # has an upstream option worth reusing:
  #
  #   * session preselection -> services.displayManager.defaultSession
  #     (nixpkgs asserts it names a real session, so we don't re-check it)
  #   * autologin            -> services.displayManager.autoLogin.{enable,user}
  #
  # Environments and login managers are deliberately independent: each session
  # module only registers a session with services.displayManager.sessionPackages,
  # and each login manager only reads that list. Adding a DE therefore never
  # implies a greeter, and swapping greeters never touches the DEs.
  flake.modules.nixos.desktop-options =
    { config, lib, ... }:
    let
      cfg = config.den.desktop;
      dm = config.services.displayManager;
    in
    {
      key = "den:nixos.desktop-options";

      options.den.desktop = {
        environments = lib.mkOption {
          type = lib.types.listOf (lib.types.enum sessionNames);
          default = [ ];
          example = [
            "sway"
            "gnome"
          ];
          # Two profiles on one host may both ask for the same environment
          # (katara gets "sway" from profile-workstation and profile-family);
          # list definitions concatenate, so collapse the duplicates.
          apply = lib.unique;
          description = ''
            Desktop environments to install. Every entry registers its own
            session, so several can coexist on one host and be chosen at the
            greeter. Contributed additively, so several profiles may each ask
            for one.
          '';
        };

        loginManager = lib.mkOption {
          type = lib.types.enum [
            "greetd"
            "gdm"
            "lightdm"
            "none"
          ];
          default = "greetd";
          description = ''
            Which login manager presents the session list. Any manager can
            start any installed session; use "none" for a host that logs in
            from a TTY.
          '';
        };

        sessionCommands = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          internal = true;
          description = ''
            Session name -> command to launch it, contributed by each session
            module. services.displayManager.sessionData exposes session *names*
            but not their exec lines, and greetd needs a real command for its
            fallback and autologin paths. A session may omit its command (GNOME
            does: its exec carries gdm-specific environment setup) and stays
            selectable from the greeter's session list regardless.
          '';
        };

        sessionAnchors = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          internal = true;
          example = {
            sway = "wayland-session@sway.target";
          };
          description = ''
            Session name -> the systemd *user* unit that means "this session is
            running", contributed by each session that ships no desktop shell of
            its own and therefore needs this repo to supply the companions (bar,
            notifications, locker, output management, file manager).

            Two things read it. System-level user units (blueman-applet) hang
            their WantedBy on the values, so they start under a session that
            needs them and not under one that brings its own. And whether the
            set is empty answers "does any installed session need the companion
            stack at all" -- which is how nixos.thunar and nixos.session-wayland
            gate themselves without enumerating session names.

            GNOME deliberately publishes nothing: it has a shell, and its
            session is not one this repo attaches anything to.

            The per-user half of the same idea is `den.session.anchors`
            (session/options.nix). The two cannot be one option -- Home Manager
            config cannot read NixOS config -- so each session module states its
            anchor on both sides, adjacent, in the same file.
          '';
        };
      };

      config = {
        # Every user gets every installed desktop's user-level config, so
        # whichever session they pick at the greeter is the one they configured.
        # There is deliberately no per-user selection: the greeter offers every
        # installed session to everyone anyway, so choosing per user only decided
        # whose home was *unprepared* for the session they picked.
        #
        # This is safe because nothing here is home-wide any more. A session's
        # user units follow its own den.session.anchors entry rather than
        # graphical-session.target (which every desktop starts, GNOME included),
        # and the per-desktop files that would otherwise collide are written per
        # desktop -- see thunar.nix. The session-anchors check holds that line.
        home-manager.sharedModules = map (de: self.modules.homeManager.${de}) cfg.environments;

        assertions = [
          {
            assertion = cfg.environments == [ ] || cfg.loginManager != "none" || dm.autoLogin.enable;
            message = ''
              den.desktop: environments ${lib.generators.toPretty { } cfg.environments} are
              installed but loginManager = "none" and autoLogin is disabled, so
              nothing can start a session.
            '';
          }
          {
            assertion = !dm.autoLogin.enable || lib.length cfg.environments < 2 || dm.defaultSession != null;
            message = ''
              den.desktop: autoLogin is enabled with more than one environment
              installed, so set services.displayManager.defaultSession to pick
              which session logs in. Otherwise the choice falls to whichever
              session happens to be listed first.
            '';
          }
        ];
      };
    };
}
