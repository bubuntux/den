{ self, ... }:
{
  # What a bare Wayland compositor does not ship: notifications, launcher,
  # locker, idle handling, output management, colour temperature, keyring, file
  # manager, tray applets. One feature, not nine -- see CLAUDE.md, "Session
  # Layout".
  flake.modules = {
    homeManager.session-wayland =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        inherit (config.den.session) wallpaper;
        anchors = lib.attrValues config.den.session.anchors;
        swaylock = "${pkgs.swaylock}/bin/swaylock";

        # One name for the companions to bind to, since `anchors` is a list and
        # wayland.systemd.target is a single unit.
        sessionTarget = "den-session.target";

        # For the modules that hardcode graphical-session.target and offer no
        # option to redirect. Requires= is left alone: nm-applet requires
        # tray.target, which stays correct.
        rebind = {
          Unit.PartOf = lib.mkForce [ sessionTarget ];
          Install.WantedBy = lib.mkForce [ sessionTarget ];
        };
      in
      {
        key = "den:homeManager.session-wayland";
        imports = with self.modules.homeManager; [
          session-options
          kanshi
          foot
          thunar
          power-profile-auto
          # Renders a bar per entry in den.session.bar, so it stays inert for a
          # session that contributes none.
          waybar
        ];

        # Rebinds kanshi, swayidle, clipman, dunst and ~30 other Wayland
        # services in one go; they all default their binding to this.
        wayland.systemd.target = sessionTarget;

        systemd.user.targets.den-session = {
          Unit = {
            Description = "Companion services for a bare Wayland session";
            # PartOf, not BindsTo, and nothing Requires an anchor -- so starting
            # this target can never start a compositor.
            PartOf = anchors;
            After = anchors;
          };
          Install.WantedBy = anchors;
        };

        # Every swaylock invocation reads this, so none of them pass an image.
        programs.swaylock = {
          enable = true;
          settings = {
            image = wallpaper;
            scaling = "fill";
          };
        };

        services.swayidle = {
          enable = true;
          events = {
            before-sleep = "${swaylock} -f";
            lock = "${swaylock} -f";
          };
          # Blanking outputs is the compositor's own call, so each session
          # appends that timeout; these two work anywhere.
          timeouts = [
            {
              timeout = 300;
              command = "${swaylock} -f";
            }
            {
              timeout = 900;
              command = "${pkgs.systemd}/bin/systemctl suspend";
            }
          ];
        };

        services.mako = {
          enable = true;
          settings.default-timeout = 5000;
        };

        programs.rofi = {
          enable = true;
          theme = "Arc-Dark";
          package = pkgs.rofi;
          extraConfig = {
            show-icons = true;
          };
        };

        # Night value shared with GNOME's Night Light (night-light.nix) so a
        # machine running both looks the same after dark.
        services.gammastep = {
          enable = true;
          provider = "geoclue2";
          temperature = {
            day = 6500;
            night = self.lib.nightLightKelvin;
          };
        };
        systemd.user.services.gammastep = rebind;

        # geoclue serves no client until an agent is registered for the user;
        # GNOME uses gnome-shell, a bare session brings its own. locale.nix
        # keeps its desktop id whitelisted.
        systemd.user.services.geoclue-agent = {
          Unit = {
            Description = "Geoclue agent for the Wayland session";
            PartOf = [ sessionTarget ];
          };
          Service = {
            Type = "exec";
            ExecStart = "${pkgs.geoclue2-with-demo-agent}/libexec/geoclue-2.0/demos/agent";
            Restart = "on-failure";
          };
          Install.WantedBy = [ sessionTarget ];
        };

        services.network-manager-applet.enable = true;
        systemd.user.services.network-manager-applet = rebind;

        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = false;
          # A session adds its own config.<session> block and backends on top.
          config.common.default = "gtk";
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        # Overrides the system entry, which is NotShowIn=GNOME;KDE and so would
        # autostart here. See CLAUDE.md, "XDG autostart".
        xdg.configFile."autostart/ibus-daemon.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=IBus
          Hidden=true
        '';

        # Default keyring, so PAM-unlocked secrets need no prompt.
        xdg.dataFile."keyrings/default" = {
          text = "login";
          force = true;
        };

        # Claims org.freedesktop.secrets from inside the session by adopting the
        # daemon PAM already unlocked. See CLAUDE.md, "Keyring".
        services.gnome-keyring = {
          enable = true;
          components = [
            "pkcs11"
            "secrets"
            "ssh"
          ];
        };

        # Deliberately no xdg.userDirs.desktop override: it is home-wide, and
        # dropping ~/Desktop for Sway would drop it for GNOME in the same home.
        home.packages = with pkgs; [
          clipman
          mako
          slurp
          warpd
          swayidle
          wl-clipboard
          wdisplays
          playerctl
          brightnessctl
          pulseaudio
          lxqt.lxqt-policykit
          xarchiver # GUI archive manager
        ];
      };

    # System half. Gated on sessionAnchors rather than on any one compositor,
    # because `imports` escapes a session's mkIf -- see CLAUDE.md.
    nixos.session-wayland =
      { config, lib, ... }:
      {
        key = "den:nixos.session-wayland";
        imports = with self.modules.nixos; [
          desktop-options
          thunar
        ];

        config = lib.mkIf (config.den.desktop.sessionAnchors != { }) {
          # Same answer for every bare compositor, so it lives here; a session
          # only registers its own entry.
          programs.uwsm.enable = true;

          security.pam.services.swaylock = { };

          # Real-time priority for users
          security.pam.loginLimits = [
            {
              domain = "@users";
              item = "rtprio";
              type = "-";
              value = 1;
            }
          ];

          security.polkit.enable = true;

          # GDM derives its PAM config from the login service, so this covers
          # both greeters.
          services.gnome.gnome-keyring.enable = true;
          security.pam.services.login.enableGnomeKeyring = true;

          # Nothing here for blueman-applet or other tray applets: uwsm's XDG
          # autostart target starts them. See CLAUDE.md, "XDG autostart".
        };
      };
  };
}
