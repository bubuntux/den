{ self, ... }:
{
  # What a bare Wayland compositor does not ship. Sway, and any scrolling or
  # tiling compositor added next, gives you windows and nothing else: no
  # notification daemon, launcher, screen locker, idle handling, output manager,
  # colour temperature, keyring, file manager or tray applets. GNOME has all of
  # it, so none of this belongs to a bundle -- it belongs to the sessions that
  # come up bare, and it is one feature ("the parts a compositor omits") rather
  # than nine, because no host would want a subset.
  #
  # Everything here passes CLAUDE.md's test for shared placement: it does not
  # name a compositor. What does -- keybindings, window rules, the bar's
  # sway/workspaces modules, the wlroots screencast chooser -- stays in
  # session/sway/.
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

        # One name for every companion below to bind to. The indirection earns
        # its keep because `anchors` is a list -- a user may carry two desktops
        # -- while Home Manager's wayland.systemd.target is a single unit: this
        # target is started by whichever session the user logged into and stopped
        # with it, so the companions name one unit and still follow the user
        # between sessions.
        sessionTarget = "den-session.target";

        # gammastep and nm-applet hardcode graphical-session.target and offer no
        # option to redirect, unlike the ~35 modules that honour
        # wayland.systemd.target, so their units are rebound by hand. Requires=
        # is deliberately untouched: nm-applet requires tray.target, which stays
        # correct.
        rebind = {
          Unit.PartOf = lib.mkForce [ sessionTarget ];
          Install.WantedBy = lib.mkForce [ sessionTarget ];
        };
      in
      {
        key = "den:homeManager.session-wayland";
        imports = with self.modules.homeManager; [
          session-options
          # Output management. Every compositor that would import this module
          # speaks wlr-output-management, and it is mutter's job under GNOME, so
          # this sits here rather than in a bundle.
          kanshi
          foot
          # A bare session has no file manager either; GNOME keeps nautilus.
          thunar
          # Stops swayidle at login when on AC -- swayidle's companion, so it
          # follows swayidle into the shared layer.
          power-profile-auto
        ];

        # Home Manager's generalization of the per-module `systemdTarget` /
        # `systemd.targets` options: kanshi, swayidle, clipman, dunst and some
        # thirty other Wayland services default their binding to it, so this one
        # assignment rebinds all of them off graphical-session.target -- which
        # every desktop starts, GNOME included. See session/options.nix for the
        # bugs that caused.
        wayland.systemd.target = sessionTarget;

        systemd.user.targets.den-session = {
          Unit = {
            Description = "Companion services for a bare Wayland session";
            # PartOf, not BindsTo: the companions stop when the session that
            # started them stops. Nothing here Requires an anchor, so starting
            # this target can never start a compositor.
            PartOf = anchors;
            After = anchors;
          };
          Install.WantedBy = anchors;
        };

        # Lock screen: show the wallpaper instead of a blank/white screen. Every
        # swaylock invocation (the swayidle events below, and each session's own
        # lock key) reads this generated ~/.config/swaylock/config, so none of
        # them need to pass an image flag.
        programs.swaylock = {
          enable = true;
          settings = {
            image = wallpaper;
            scaling = "fill";
          };
        };

        # Binds to sessionTarget through wayland.systemd.target, as do the other
        # services below that take no explicit target.
        services.swayidle = {
          enable = true;
          events = {
            before-sleep = "${swaylock} -f";
            lock = "${swaylock} -f";
          };
          # Blanking the outputs is the one idle action only the compositor can
          # do, so each session appends a timeout for that; these two work
          # anywhere. Suspend is what actually sleeps a docked laptop once logind
          # has stopped handling the lid (see profile-workstation), and
          # power-profile-auto runs swayidle on battery only, so it never fires
          # on AC.
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

        # Screen colour temperature. Daytime stays at gammastep's neutral 6500K;
        # the night value is shared with GNOME's Night Light
        # (features/desktop/night-light.nix) so a machine running both looks the
        # same after dark.
        services.gammastep = {
          enable = true;
          provider = "geoclue2";
          temperature = {
            day = 6500;
            night = self.lib.nightLightKelvin;
          };
        };
        systemd.user.services.gammastep = rebind;

        # Gammastep asks geoclue where we are, and geoclue serves no client until
        # an agent is registered for that user -- GNOME uses gnome-shell, so a
        # bare session has to bring its own. It prompts through mako, and waits
        # for geoclue's bus name itself, so ordering does not matter.
        # features/system/locale.nix keeps its desktop id whitelisted.
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

        # The network applet used to reach every user on the host through
        # bundle-desktop's home-manager.sharedModules, which put a second network
        # icon in the GNOME session next door. It belongs to the sessions with no
        # tray of their own.
        services.network-manager-applet.enable = true;
        systemd.user.services.network-manager-applet = rebind;

        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = false;
          # Only the fallback and the gtk implementation are shared; a session
          # adds its own `config.<session>` block and whatever backend is
          # specific to it (Sway adds xdg-desktop-portal-wlr for screen
          # capture). Both options merge, so the session half is additive.
          config.common.default = "gtk";
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        # Don't autostart IBus. uwsm brought XDG autostart with it -- something
        # a bare compositor never had -- so /etc/xdg/autostart entries now run
        # here, and ibus-daemon.desktop is marked `NotShowIn=GNOME;KDE`, i.e.
        # "start me in every other desktop". It arrives because GNOME is
        # installed on the same host, greets each login with a notification, and
        # nobody here types through an input method.
        #
        # A user entry of the same name overrides the system one, and `Hidden`
        # means "treat as absent". GNOME is unaffected either way: it starts ibus
        # from gnome-shell rather than from autostart, which is exactly why the
        # system entry excludes itself there.
        xdg.configFile."autostart/ibus-daemon.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=IBus
          Hidden=true
        '';

        # Make `login` the default keyring so PAM-unlocked secrets are usable by
        # libsecret apps (Claude Code, browsers, ...) without a prompt.
        xdg.dataFile."keyrings/default" = {
          text = "login";
          force = true;
        };

        # Own org.freedesktop.secrets from inside the graphical session. PAM
        # unlocks a keyring daemon with the login password at login (greetd and
        # GDM both do), but PAM runs before the user dbus socket exists, so that
        # daemon never claims the session bus and then dies. Left alone, the
        # first libsecret app dbus-activates a fresh, LOCKED daemon minutes later
        # and you get a password prompt. This user service runs
        # `gnome-keyring-daemon --start` while the PAM daemon is still alive: it
        # adopts that already-unlocked daemon through its control socket and
        # claims the bus, so apps see an unlocked keyring. The system dbus
        # activation file is kept as a fallback (e.g. for protonvpn-app) if PAM
        # ever fails to start or unlock the daemon.
        #
        # Left on graphical-session-pre.target, where Home Manager puts it and
        # where it belongs: it has to be up before anything asks for a secret,
        # which is earlier than any session anchor. `--start` adopts a running
        # daemon rather than adding a second one, so it stays harmless in a
        # session that already unlocked one.
        services.gnome-keyring = {
          enable = true;
          components = [
            "pkcs11"
            "secrets"
            "ssh"
          ];
        };

        # Deliberately no `xdg.userDirs.desktop = home` here. A tiling session
        # draws no desktop icons, so the folder is useless in it -- but every
        # user on the host now carries every installed desktop's config, and this
        # is a *home*-wide setting with no per-session form, so skipping the
        # folder for Sway would also take it away from the same user's GNOME
        # session. An unused ~/Desktop is the cheaper of the two.
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

    # System half: what the companions above need that cannot be done per user.
    #
    # Gated on den.desktop.sessionAnchors being non-empty -- that is, on some
    # installed session needing the companion stack -- because bundle-desktop
    # imports every session unconditionally and `imports` is not covered by the
    # mkIf a session wraps its config in. Without the gate this lands on a
    # GNOME-only host and gives it a swaylock PAM stack it can never use.
    nixos.session-wayland =
      { config, lib, ... }:
      {
        key = "den:nixos.session-wayland";
        imports = with self.modules.nixos; [
          desktop-options
          # Installing a file manager cannot be done per user; the folder
          # association that goes with it is the home half, imported above.
          thunar
        ];

        config = lib.mkIf (config.den.desktop.sessionAnchors != { }) {
          # Wrap every bare compositor in a systemd user session. Enabled here
          # rather than by any one session module, because it is the same answer
          # for all of them and this module is what "some installed session ships
          # no shell of its own" already means. A session only registers its own
          # `programs.uwsm.waylandCompositors.<name>` entry.
          #
          # It is what makes the anchors uniform: wayland-session@<id>.target for
          # every compositor, where upstream otherwise gives you Home Manager's
          # target for Sway, niri.service for niri, and nothing at all for
          # mangowc. Note it also switches dbus to the broker implementation,
          # which uwsm recommends.
          programs.uwsm.enable = true;

          # PAM for swaylock, which every bare session locks with.
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

          # Keyring for secrets, and auto-unlock at login so apps (e.g. Claude
          # Code) don't prompt. GDM derives its PAM config from the login
          # service, so this covers both greeters.
          services.gnome.gnome-keyring.enable = true;
          security.pam.services.login.enableGnomeKeyring = true;

          # Deliberately nothing here for blueman-applet. Its unit ships no
          # [Install] section, so a bare session used to leave the tray applet
          # unstarted and this module bound it to the anchors by hand. uwsm
          # brought `wayland-session-xdg-autostart@<id>.target` with it, which
          # starts /etc/xdg/autostart entries the way a full desktop does --
          # blueman.desktop among them -- so the hand-wiring became a second
          # copy of the same applet rather than the only one.
          #
          # That is the general rule now: anything with an XDG autostart entry
          # needs no wiring from us. Only things with no entry at all -- the
          # geoclue agent, the idle inhibitor -- are bound explicitly, and those
          # are per-user units in the Home Manager half above.
        };
      };
  };
}
