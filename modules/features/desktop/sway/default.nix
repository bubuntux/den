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
    { pkgs, lib, ... }:
    let
      # Import configuration fragments (curried functions, underscore prefix to avoid import-tree)
      keybindings = import ./_keybindings.nix pkgs mod;
      rules = import ./_rules.nix;
      modes = import ./_modes.nix pkgs mod;
      startup = import ./_startup.nix pkgs;
    in
    {
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

          # Wallpaper
          output."*".bg = "${wallpaper} fill";

          # Style
          window = {
            border = 3;
            commands = rules;
          };

          floating.modifier = "${mod} normal";

          focus.followsMouse = "always";
          focus.mouseWarping = "output";

          gaps = {
            inner = 3;
            outer = 3;
            smartBorders = "on";
            smartGaps = true;
          };

          # Workspace to output assignments
          workspaceOutputAssign = [
            {
              workspace = "1";
              output = [
                "DP-5"
                "DP-6"
              ];
            }
            {
              workspace = "2";
              output = [
                "DP-5"
                "DP-6"
              ];
            }
            {
              workspace = "3";
              output = [
                "DP-5"
                "DP-6"
              ];
            }
            {
              workspace = "4";
              output = [
                "DP-7"
                "DP-8"
                "DP-9"
              ];
            }
            {
              workspace = "5";
              output = [
                "DP-7"
                "DP-8"
                "DP-9"
              ];
            }
            {
              workspace = "6";
              output = [
                "DP-7"
                "DP-8"
                "DP-9"
              ];
            }
            {
              workspace = "7";
              output = [
                "DP-7"
                "DP-8"
                "DP-9"
              ];
            }
            {
              workspace = "8";
              output = "eDP-1";
            }
            {
              workspace = "9";
              output = "eDP-1";
            }
            {
              workspace = "10";
              output = "eDP-1";
            }
          ];

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

      # Waybar (started by sway)
      programs.waybar.enable = true;

      # XDG portal configuration
      xdg.portal = {
        enable = true;
        xdgOpenUsePortal = true;
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
      ];
    };

  # NixOS module for system-level sway configuration
  flake.nixosModules.sway =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        bundle-desktop
        waybar
        kanshi
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

      # Add home-manager sway module to shared modules
      home-manager.sharedModules = [ self.homeModules.sway ];
    };
}
