{
  self,
  ...
}:
let
  # NixOS wallpaper
  wallpaper = builtins.fetchurl {
    url = "https://github.com/NixOS/nixos-artwork/blob/63f68a917f4e8586c5d35e050cdaf1309832272d/wallpapers/nix-wallpaper-binary-black_8k.png?raw=true";
    sha256 = "331120bf35a676a31e23919e23a1f3722eb277988be383435f22903aec3e7cb6";
  };

  # Modifier key
  mod = "Mod4";
in
{
  # Home Manager module for sway user configuration
  flake.homeModules.sway =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # Import configuration fragments (curried functions, underscore prefix to avoid import-tree)
      keybindings = import ./_keybindings.nix pkgs mod;
      rules = import ./_rules.nix;
      modes = import ./_modes.nix pkgs mod;
      startup = import ./_startup.nix pkgs;

      # Generate workspace output assignments from monitors config
      # Each monitor with workspaces generates entries mapping those workspaces to the monitor
      workspaceAssignments = lib.flatten (
        map (
          m:
          map (ws: {
            workspace = ws;
            output = m.name;
          }) m.workspaces
        ) (lib.filter (m: m.workspaces != [ ]) config.monitors)
      );
    in
    {
      # Note: monitors module must be imported by the parent NixOS module
      imports = with self.homeModules; [
        foot
      ];
      wayland.windowManager.sway = {
        enable = true;
        systemd.enable = true;
        wrapperFeatures = {
          base = true;
          gtk = true;
        };
        extraOptions = [ "--unsupported-gpu" ];

        extraSessionCommands = ''
          export SDL_VIDEODRIVER=wayland
          export QT_QPA_PLATFORM=wayland
          export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
          export _JAVA_AWT_WM_NONREPARENTING=1
          export MOZ_ENABLE_WAYLAND=1
          export NIXOS_OZONE_WL=1
          export WLR_NO_HARDWARE_CURSORS=1
        '';

        config = {
          modifier = mod;
          terminal = "foot";
          menu = "rofi -terminal foot -show combi -combi-modes drun#run -modes combi";

          # Enable Num Lock by default
          input."type:keyboard".xkb_numlock = "enabled";

          # Wallpaper
          output."*".bg = "${wallpaper} fill";

          # Style
          window = {
            border = 3;
            titlebar = false;
            commands = rules;
          };

          floating.modifier = "${mod} normal";

          focus.followMouse = "always";
          focus.mouseWarping = "output";

          gaps = {
            inner = 3;
            outer = 3;
            smartBorders = "on";
            smartGaps = true;
          };

          # Workspace to output assignments (generated from monitors config)
          workspaceOutputAssign = workspaceAssignments;

          keybindings = lib.mkOptionDefault keybindings;
          modes = modes;

          # Bars - use waybar
          bars = [ ];

          # Startup commands
          startup = startup.commands;
        };
      };

      # Swayidle configuration
      services.swayidle = startup.swayidle;

      # Mako notification daemon
      services.mako = startup.mako;

      # Rofi launcher
      programs.rofi = startup.rofi;

      # Waybar (started via systemd service)
      programs.waybar.enable = true;

      # Gammastep for screen color temperature (night light)
      services.gammastep = {
        enable = true;
        provider = "geoclue2";
        temperature = {
          day = 6500;
          night = 4000;
        };
      };

      # XDG portal configuration
      xdg.portal = {
        enable = true;
        xdgOpenUsePortal = false;
        config = {
          common.default = "gtk";
          sway = {
            default = [ "gtk" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
          };
        };
        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
        ];
      };

      # Make `login` the default keyring so PAM-unlocked secrets are usable
      # by libsecret apps (Claude Code, browsers, ...) without a prompt.
      xdg.dataFile."keyrings/default" = {
        text = "login";
        force = true;
      };

      # Own org.freedesktop.secrets from inside the graphical session.
      # greetd's PAM `auto_start` (configured below) unlocks a keyring daemon
      # with the login password at login, but PAM runs before the user dbus
      # socket exists, so that daemon never claims the session bus and then
      # dies. Left alone, the first libsecret app dbus-activates a fresh,
      # LOCKED daemon minutes later and you get a password prompt. This user
      # service runs `gnome-keyring-daemon --start` at graphical-session start,
      # while the PAM daemon is still alive: it adopts that already-unlocked
      # daemon via its control socket and claims the bus, so apps see an
      # unlocked keyring. The system dbus activation file is kept as a fallback
      # (e.g. for protonvpn-app) if PAM ever fails to start/unlock the daemon.
      services.gnome-keyring = {
        enable = true;
        components = [
          "pkcs11"
          "secrets"
          "ssh"
        ];
      };

      # Sway has no desktop icons, so skip the Desktop folder.
      xdg.userDirs.desktop = config.home.homeDirectory;

      # Packages
      home.packages = with pkgs; [
        clipman
        mako
        waybar
        slurp
        warpd
        swaylock
        swayidle
        sway-contrib.grimshot
        wl-clipboard
        wdisplays
        playerctl
        brightnessctl
        pulseaudio
        lxqt.lxqt-policykit
        xarchiver # GUI archive manager
      ];
    };

  # NixOS module for system-level sway configuration
  flake.nixosModules.sway =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        bundle-desktop
        power-profile-auto
        waybar
        kanshi
        thunar
        unstable-packages
      ];

      # Enable sway compositor
      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
        extraPackages = with pkgs; [
          foot
          wmenu
          swaylock
          swayidle
          wl-clipboard
          mako
          grim
          slurp
        ];
      };

      # PAM configuration for swaylock
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

      # XDG portal for screen sharing and file dialogs
      xdg.portal = {
        enable = true;
        wlr.enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      };

      # Required for sway and home-manager integration
      security.polkit.enable = true;

      # Keyring for secrets
      services.gnome.gnome-keyring.enable = true;

      # Auto-unlock the keyring at login so apps (e.g. Claude Code) don't prompt
      security.pam.services.greetd.enableGnomeKeyring = true;
      security.pam.services.login.enableGnomeKeyring = true;

      # Enable greetd with tuigreet
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
            user = "greeter";
          };
        };
      };

      # The blueman-applet unit ships no [Install] section, so nothing starts it
      # at login. Full DEs (e.g. GNOME on katara) autostart it via XDG, but sway
      # has no XDG autostart -- bind it to the graphical session like waybar/mako
      # so the Bluetooth tray icon actually appears. Scoped here (not in the
      # shared bluetooth feature) to avoid a duplicate applet on GNOME hosts.
      systemd.user.services.blueman-applet = {
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
      };

      # Add home-manager sway module to shared modules
      home-manager.sharedModules = [
        self.homeModules.monitors
        self.homeModules.sway
      ];
    };
}
