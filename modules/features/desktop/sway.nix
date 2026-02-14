{
  self,
  ...
}:
{
  # Home Manager module for sway user configuration
  flake.homeModules.sway = {
    wayland.windowManager.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      config = {
        modifier = "Mod4";
        terminal = "foot";
        menu = "wmenu-run";

        bars = [
          {
            position = "top";
            statusCommand = "while date +'%Y-%m-%d %H:%M'; do sleep 60; done";
          }
        ];

        keybindings =
          let
            mod = "Mod4";
          in
          {
            "${mod}+Return" = "exec foot";
            "${mod}+d" = "exec wmenu-run";
            "${mod}+Shift+q" = "kill";
            "${mod}+Shift+e" = "exec swaymsg exit";
            "${mod}+Shift+c" = "reload";

            # Focus
            "${mod}+h" = "focus left";
            "${mod}+j" = "focus down";
            "${mod}+k" = "focus up";
            "${mod}+l" = "focus right";

            # Move
            "${mod}+Shift+h" = "move left";
            "${mod}+Shift+j" = "move down";
            "${mod}+Shift+k" = "move up";
            "${mod}+Shift+l" = "move right";

            # Workspaces
            "${mod}+1" = "workspace number 1";
            "${mod}+2" = "workspace number 2";
            "${mod}+3" = "workspace number 3";
            "${mod}+4" = "workspace number 4";
            "${mod}+5" = "workspace number 5";
            "${mod}+6" = "workspace number 6";
            "${mod}+7" = "workspace number 7";
            "${mod}+8" = "workspace number 8";
            "${mod}+9" = "workspace number 9";
            "${mod}+0" = "workspace number 10";

            # Move to workspace
            "${mod}+Shift+1" = "move container to workspace number 1";
            "${mod}+Shift+2" = "move container to workspace number 2";
            "${mod}+Shift+3" = "move container to workspace number 3";
            "${mod}+Shift+4" = "move container to workspace number 4";
            "${mod}+Shift+5" = "move container to workspace number 5";
            "${mod}+Shift+6" = "move container to workspace number 6";
            "${mod}+Shift+7" = "move container to workspace number 7";
            "${mod}+Shift+8" = "move container to workspace number 8";
            "${mod}+Shift+9" = "move container to workspace number 9";
            "${mod}+Shift+0" = "move container to workspace number 10";

            # Layout
            "${mod}+b" = "splith";
            "${mod}+v" = "splitv";
            "${mod}+f" = "fullscreen toggle";
            "${mod}+s" = "layout stacking";
            "${mod}+w" = "layout tabbed";
            "${mod}+e" = "layout toggle split";
            "${mod}+Shift+space" = "floating toggle";
            "${mod}+space" = "focus mode_toggle";
            "${mod}+a" = "focus parent";

            # Scratchpad
            "${mod}+Shift+minus" = "move scratchpad";
            "${mod}+minus" = "scratchpad show";

            # Resize mode
            "${mod}+r" = "mode resize";
          };

        modes = {
          resize = {
            "h" = "resize shrink width 10 px";
            "j" = "resize grow height 10 px";
            "k" = "resize shrink height 10 px";
            "l" = "resize grow width 10 px";
            "Return" = "mode default";
            "Escape" = "mode default";
          };
        };
      };
    };
  };

  # NixOS module for system-level sway configuration
  flake.nixosModules.sway =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        bundle-desktop
      ];

      # Enable sway compositor
      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
        extraPackages = with pkgs; [
          foot # terminal
          wmenu # application launcher
          swaylock # screen locker
          swayidle # idle management
          wl-clipboard # clipboard utilities
          mako # notification daemon
          grim # screenshot tool
          slurp # region selection
        ];
      };

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
        useTextGreeter = true;
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
