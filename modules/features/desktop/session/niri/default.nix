{ self, ... }:
{
  # niri, and only what names niri; the rest is in session/wayland.nix.
  flake.modules = {
    homeManager.niri =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        # Whichever terminal the host picked, named by its own module.
        terminal = config.den.session.terminal;
        menu = "rofi -terminal ${terminal} -show combi -combi-modes drun#run -modes combi";

        anchor = "wayland-session@niri.target";
      in
      {
        key = "den:homeManager.niri";
        # Every user on the host receives this; the anchor below is what keeps
        # it out of their other sessions.
        imports = with self.modules.homeManager; [
          session-wayland
          session-options
          waybar-niri
        ];

        # uwsm names this from the binary basename; the key is the id the
        # session announces in XDG_CURRENT_DESKTOP.
        den.session.anchors.niri = anchor;

        # Read by nothing but niri, so the file is the whole integration: this
        # Home Manager release ships no wayland.windowManager.niri. `text`
        # rather than a writeText `source`, so terminal-choice can read what is
        # in it without building anything.
        xdg.configFile."niri/config.kdl".text = import ./_config.nix {
          inherit
            pkgs
            lib
            terminal
            menu
            ;
        };

        # programs.niri has no extraSessionCommands, so the toolkit variables go
        # where uwsm looks for them. `env-<desktop>`, not `env`, so a GNOME login
        # in the same home never reads them.
        xdg.configFile."uwsm/env-niri".text = ''
          export NIXOS_OZONE_WL=1
          export QT_QPA_PLATFORM=wayland
          export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
          export MOZ_ENABLE_WAYLAND=1
          export SDL_VIDEODRIVER=wayland
          export _JAVA_AWT_WM_NONREPARENTING=1
        '';

        # niri paints a flat colour behind the session and has no wallpaper of
        # its own, so one layer-shell client supplies what sway's `output * bg`
        # does. wbg rather than swaybg: same protocol, no sway in the closure.
        systemd.user.services.niri-wallpaper = {
          Unit = {
            Description = "Wallpaper for the niri session";
            PartOf = [ anchor ];
            After = [ anchor ];
            ConditionEnvironment = "WAYLAND_DISPLAY";
          };
          Service = {
            ExecStart = "${lib.getExe pkgs.wbg} ${config.den.session.wallpaper}";
            Restart = "on-failure";
          };
          Install.WantedBy = [ anchor ];
        };

        # The one idle timeout that cannot be shared; the list merges with
        # session/wayland.nix. No resumeCommand: niri powers the outputs back on
        # by itself at the next input event.
        services.swayidle.timeouts = [
          {
            timeout = 360;
            command = "${lib.getExe pkgs.niri} msg action power-off-monitors";
          }
        ];

        # Screen capture goes through xdg-desktop-portal-gnome, which is the
        # backend niri implements (its `xdp-gnome-screencast` build feature); the
        # shared layer sets enable, the fallback and gtk.
        xdg.portal = {
          config.niri = {
            default = [
              "gnome"
              "gtk"
            ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
          };
          extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
        };
      };

    nixos.niri =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        key = "den:nixos.niri";
        imports = with self.modules.nixos; [
          desktop-options
          # Gates itself on den.desktop.sessionAnchors, so importing it here is
          # safe even though `imports` escapes the mkIf below.
          session-wayland
        ];

        config = lib.mkIf (lib.elem "niri" config.den.desktop.environments) {
          programs.niri = {
            enable = true;

            # FileChooser stays gtk, which is what session/wayland.nix already
            # asks for -- and a bare session here gets thunar, not nautilus.
            useNautilus = false;

            # One session entry, and it starts uwsm: rewrite the one the package
            # ships (Exec=niri-session, which binds the session to
            # graphical-session.target and so gets none of the companions).
            # A symlinkJoin rather than overrideAttrs -- see CLAUDE.md, "Adding a
            # desktop environment".
            package = pkgs.symlinkJoin {
              name = "niri-uwsm-session-${pkgs.niri.version}";
              paths = [ pkgs.niri ];
              inherit (pkgs.niri) meta passthru;
              postBuild = ''
                rm $out/share/wayland-sessions/niri.desktop
                cat > $out/share/wayland-sessions/niri.desktop <<'EOF'
                [Desktop Entry]
                Name=Niri
                Comment=A scrollable-tiling Wayland compositor, started by uwsm
                Exec=${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/niri
                Type=Application
                DesktopNames=niri
                EOF
              '';
            };
          };

          # X11 clients reach niri through xwayland-satellite, which the
          # generated config names by store path; this is only so it is
          # inspectable on the machine.
          environment.systemPackages = [ pkgs.xwayland-satellite ];

          # greetd needs a command rather than an entry; same one, so both
          # greeters take the identical path.
          den.desktop.sessionCommands.niri = "${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/niri";

          # System-side half of den.session.anchors above.
          den.desktop.sessionAnchors.niri = "wayland-session@niri.target";
        };
      };
  };
}
