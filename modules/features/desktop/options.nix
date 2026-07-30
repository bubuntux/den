{ self, ... }:
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
          type = lib.types.listOf (
            lib.types.enum [
              "sway"
              "gnome"
            ]
          );
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

        users = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.enum [
              "sway"
              "gnome"
            ]
          );
          default = { };
          example = {
            bbtux = "sway";
            shari = "gnome";
          };
          description = ''
            Which environment's *user-level* (Home Manager) config each user
            gets. Needed separately from `environments` because that only
            installs sessions system-wide: with two environments installed,
            pushing both DEs' Home Manager config at every user would collide
            (each configures xdg.portal, keybindings, bars). The greeter still
            decides which session a user actually starts.
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
      };

      config = {
        # Bind each user to one DE's Home Manager config. `home-manager.users`
        # merges with the definition in the user module, so this adds to it
        # rather than replacing it.
        home-manager.users = lib.mapAttrs (_: de: {
          imports = [ self.modules.homeManager.${de} ];
        }) cfg.users;

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
            assertion = lib.all (de: lib.elem de cfg.environments) (lib.attrValues cfg.users);
            message = ''
              den.desktop.users assigns an environment that is not in
              den.desktop.environments: users = ${lib.generators.toPretty { } cfg.users},
              environments = ${lib.generators.toPretty { } cfg.environments}.
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
