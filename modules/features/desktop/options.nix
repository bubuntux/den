{ self, ... }:
let
  # The environments this repo knows how to install. Adding a desktop is one
  # entry here plus its session file and a bundle-desktop import.
  sessionNames = [
    "sway"
    "niri"
    "gnome"
  ];

  # Both are Home Manager module names, which is what makes the option values
  # the lookup in session/wayland.nix.
  barNames = [
    "waybar"
    "ironbar"
  ];

  terminalNames = [
    "ghostty"
    "foot"
  ];
in
{
  # Two knobs only -- what to install, and which greeter presents it. Session
  # preselection and autologin already have upstream options. See CLAUDE.md.
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
          # Two profiles may ask for the same environment; lists concatenate.
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

        bar = lib.mkOption {
          type = lib.types.enum barNames;
          default = "waybar";
          description = ''
            Which status bar a session starts. Single-valued, so the host picks
            it; the value is a Home Manager module name and session-wayland
            pushes the match.

            The two differ in more than looks: waybar builds one bar per
            session out of den.session.bar, ironbar builds one bar for all of
            them. See CLAUDE.md, "Choosing a bar".
          '';
        };

        barsInstalled = lib.mkOption {
          type = lib.types.listOf (lib.types.enum barNames);
          default = [ cfg.bar ];
          defaultText = lib.literalExpression "[ config.den.desktop.bar ]";
          apply = lib.unique;
          description = ''
            Which bars get units at all. Everything here but `bar` is installed
            and never started, so `systemctl --user start <other>` compares them
            inside one session with no rebuild -- at the cost of its closure,
            which for ironbar next to waybar is ~210 MiB.
          '';
        };

        terminal = lib.mkOption {
          type = lib.types.enum terminalNames;
          default = "ghostty";
          description = ''
            Which terminal a session installs and its keybindings spawn.
            Single-valued, so the host picks it; the value is a Home Manager
            module name and session-wayland pushes the match.

            The command is not the module name -- foot is reached through
            footclient -- so the module states its own in den.session.terminal.
            See CLAUDE.md, "Choosing a terminal".
          '';
        };

        sessionCommands = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          internal = true;
          description = ''
            Session name -> command to launch it, contributed by each session
            module: greetd needs a real command, and sessionData exposes names
            only. A session may omit it (GNOME does) and stay selectable.
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
            running", contributed by each session that ships no shell of its own.
            System-level user units bind to the values, and an empty set means no
            installed session needs the companion stack -- which is how
            nixos.thunar and nixos.session-wayland gate themselves.

            The per-user half is `den.session.anchors`; Home Manager cannot read
            NixOS config, so each session states both, adjacent.
          '';
        };
      };

      config = {
        # Every user gets every installed desktop; the anchors keep them apart
        # at runtime. No per-user selection -- see CLAUDE.md.
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
            assertion = lib.elem cfg.bar cfg.barsInstalled;
            message = ''
              den.desktop: bar = "${cfg.bar}" is not in barsInstalled
              (${lib.generators.toPretty { } cfg.barsInstalled}), so the bar the
              session starts would have no units.
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
