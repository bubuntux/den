{ self, ... }:
{
  flake.modules.nixos.login-greetd =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.den.desktop;
      dm = config.services.displayManager;
      sessionDirs = "${dm.sessionData.desktops}/share";
      # greetd is the one manager that ignores services.displayManager
      # .defaultSession (its own option doc says the setting is GDM/LightDM/SDDM
      # only), so translate it here into tuigreet's --cmd fallback. Only sessions
      # that published a command can be used this way.
      defaultCommand =
        if dm.defaultSession != null then cfg.sessionCommands.${dm.defaultSession} or null else null;
      autologinCommand =
        if dm.sessionData.autologinSession != null then
          cfg.sessionCommands.${dm.sessionData.autologinSession} or null
        else
          null;
    in
    {
      key = "den:nixos.login-greetd";
      imports = [ self.modules.nixos.desktop-options ];

      config = lib.mkIf (cfg.loginManager == "greetd") {
        services.greetd = {
          enable = true;
          # tuigreet is a TUI: without this, systemd boot messages scribble over it.
          useTextGreeter = true;

          # --sessions/--xsessions point at every session registered by the
          # enabled environments, so adding a DE to den.desktop.environments is
          # all it takes to make it appear here.
          # --remember pre-fills the last username (so a single-user host only
          # types a password, which keeps gnome-keyring auto-unlock working).
          # --remember-user-session records the session *per user*, which is how
          # two users on one host end up in different desktops.
          settings.default_session.command = lib.concatStringsSep " " (
            [
              (lib.getExe pkgs.tuigreet)
              "--time"
              "--remember"
              "--remember-user-session"
              "--sessions ${sessionDirs}/wayland-sessions"
              "--xsessions ${sessionDirs}/xsessions"
            ]
            ++ lib.optional (defaultCommand != null) "--cmd ${defaultCommand}"
          );
          settings.default_session.user = "greeter";

          # Autologin. greetd re-runs initial_session on every restart, which is
          # why the upstream module turns `restart` off by itself once
          # initial_session is set -- no need to do it here.
          settings.initial_session = lib.mkIf (dm.autoLogin.enable && autologinCommand != null) {
            command = autologinCommand;
            user = dm.autoLogin.user;
          };
        };

        # Auto-unlock the keyring at login so apps (e.g. Claude Code) don't
        # prompt. Upstream already defaults this to gnome-keyring.enable; set it
        # explicitly so the intent survives a change to that default.
        security.pam.services.greetd.enableGnomeKeyring =
          lib.mkIf config.services.gnome.gnome-keyring.enable true;

        warnings = lib.optional (dm.defaultSession != null && defaultCommand == null) ''
          den.desktop: services.displayManager.defaultSession = "${dm.defaultSession}"
          has no den.desktop.sessionCommands entry, so greetd cannot preselect it.
          The session is still listed in the greeter; tuigreet will remember it
          per user after the first login.
        '';

        assertions = [
          {
            assertion = !dm.autoLogin.enable || autologinCommand != null;
            message = ''
              den.desktop: autoLogin is enabled with loginManager = "greetd", but
              session "${toString dm.sessionData.autologinSession}" publishes no
              den.desktop.sessionCommands entry, and greetd needs a real command
              to start a session unattended. Use gdm/lightdm for this session, or
              set services.greetd.settings.initial_session by hand.
            '';
          }
          {
            assertion = !dm.autoLogin.enable || dm.autoLogin.user != null;
            message = "den.desktop: services.displayManager.autoLogin.user must be set when autoLogin is enabled.";
          }
        ];
      };
    };
}
