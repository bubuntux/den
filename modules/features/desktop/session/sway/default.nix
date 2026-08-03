{
  self,
  ...
}:
let
  # Modifier key
  mod = "Mod4";
in
{
  # Sway, and only what names Sway; the rest is in session/wayland.nix.
  flake.modules = {
    homeManager.sway =
      {
        pkgs,
        lib,
        config,
        options,
        ...
      }:
      let
        # Import configuration fragments (curried functions, underscore prefix to avoid import-tree)
        keybindings = import ./_keybindings.nix pkgs mod;
        rules = import ./_rules.nix;
        modes = import ./_modes.nix pkgs mod;
        startupCommands = import ./_startup.nix pkgs;

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
        key = "den:homeManager.sway";
        # Every user on the host receives this; the anchor below is what keeps
        # it out of their other sessions.
        imports = with self.modules.homeManager; [
          session-wayland
          session-options
          monitors
          waybar-sway
          # dictation
        ];

        # uwsm names this from the binary basename; the key is the id the
        # session announces in XDG_CURRENT_DESKTOP.
        den.session.anchors.sway = "wayland-session@sway.target";

        wayland.windowManager.sway = {
          enable = true;

          # Config only: uwsm starts the system wrapper by absolute path, so
          # that is the one that must carry the session environment.
          package = null;

          # uwsm owns startup; Home Manager must not also generate
          # sway-session.target and race to start it.
          systemd.enable = false;

          config = {
            modifier = mod;
            terminal = "foot";
            menu = "rofi -terminal foot -show combi -combi-modes drun#run -modes combi";

            # Enable Num Lock by default
            input."type:keyboard".xkb_numlock = "enabled";

            # Wallpaper. The lock screen reads the same image from
            # den.session.wallpaper (session/wayland.nix).
            output."*".bg = "${config.den.session.wallpaper} fill";

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

            # `uwsm finalize` first and mandatory: the unit is Type=notify.
            # WAYLAND_DISPLAY and DISPLAY come for free; everything named here is
            # needed outside sway's process tree (SWAYSOCK above all -- it is how
            # waybar finds the compositor).
            startup = [
              {
                command = "${pkgs.uwsm}/bin/uwsm finalize ${
                  lib.concatStringsSep " " [
                    "SWAYSOCK"
                    "I3SOCK"
                    "XDG_CURRENT_DESKTOP"
                    "XDG_SESSION_TYPE"
                    "NIXOS_OZONE_WL"
                    "XCURSOR_THEME"
                    "XCURSOR_SIZE"
                    "QT_QPA_PLATFORM"
                    "QT_WAYLAND_DISABLE_WINDOWDECORATION"
                    "MOZ_ENABLE_WAYLAND"
                    "SDL_VIDEODRIVER"
                    "_JAVA_AWT_WM_NONREPARENTING"
                  ]
                }";
              }
            ]
            ++ startupCommands;
          };
        };

        # The one idle timeout that cannot be shared; the list merges with
        # session/wayland.nix.
        services.swayidle.timeouts = [
          {
            timeout = 360;
            command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
            resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
          }
        ];

        # Adds only what is specific to wlroots screen capture; the shared
        # layer sets enable, the fallback and gtk.
        xdg.portal = {
          config.sway = {
            default = [ "gtk" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
          };
          extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
        };

        # grimshot drives sway's screenshot IPC; waybar comes from programs.waybar.
        home.packages = [ pkgs.sway-contrib.grimshot ];
      };

    # NixOS module for system-level sway configuration
    nixos.sway =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        # Screen-share picker for xdg-desktop-portal-wlr, which draws none of its
        # own. Returns the token xdpw expects: "Monitor: <output>" or
        # "Window: <ext-foreign-toplevel-list-v1 id>".
        screencastChooser = pkgs.writeShellApplication {
          name = "sway-screencast-chooser";
          runtimeInputs = with pkgs; [
            sway
            jq
            lswt
            rofi
          ];
          text = ''
            tokens=()
            labels=()

            # Displays are often the same model, so label with resolution,
            # position, orientation and a ★ on the focused output.
            while IFS=$'\t' read -r name label; do
              tokens+=("Monitor: $name")
              labels+=("$label")
            done < <(swaymsg -t get_outputs | jq -r '
              [ .[] | select(.active) ] as $o
              | ($o | map(.rect.x) | min) as $minx
              | ($o | map(.rect.x) | max) as $maxx
              | $o[]
              | ( (.rect.width | tostring) + "×" + (.rect.height | tostring) ) as $res
              | ( (.current_mode.refresh / 1000) | round | tostring ) as $hz
              | ( if .rect.width > .rect.height then "landscape" else "portrait" end ) as $orient
              | ( if $minx == $maxx then "" elif .rect.x == $minx then "left·" elif .rect.x == $maxx then "right·" else "center·" end ) as $pos
              | ( if .focused then " ★" else "" end ) as $foc
              | [ .name,
                  ("🖵  " + .name + "  " + (.model // "?") + "  " + $res + "@" + $hz + "Hz  " + $pos + $orient + $foc)
                ] | @tsv')

            # Open windows via ext-foreign-toplevel-list-v1 (lswt supplies the id).
            while IFS=$'\t' read -r id app title; do
              tokens+=("Window: $id")
              labels+=("🗔  $app — $title")
            done < <(lswt -j \
              | jq -r '.toplevels[]? | [.identifier, (."app-id" // "?"), (.title // "")] | @tsv')

            if [ ''${#labels[@]} -eq 0 ]; then
              exit 0
            fi

            # -format i => rofi prints the selected row index; -no-custom blocks
            # free-text entries. Empty output / non-zero exit == user cancelled.
            idx=$(printf '%s\n' "''${labels[@]}" \
              | rofi -dmenu -i -no-custom -format i -p "Share") || exit 0
            [ -z "$idx" ] && exit 0

            printf '%s\n' "''${tokens[$idx]}"
          '';
        };
      in
      {
        key = "den:nixos.sway";
        imports = with self.modules.nixos; [
          desktop-options
          # Gates itself on den.desktop.sessionAnchors, so importing it here is
          # safe even though `imports` escapes the mkIf below.
          session-wayland
        ];

        config = lib.mkIf (lib.elem "sway" config.den.desktop.environments) {
          # Registers the session with sessionPackages, which is all a login
          # manager needs. The only sway anyone starts, so the session environment lives here;
          # `uwsm finalize` carries it beyond sway's process tree.
          programs.sway = {
            enable = true;

            # One session entry, and it starts uwsm: rewrite the one the package
            # ships rather than adding a second with
            # programs.uwsm.waylandCompositors. buildCommand, not postBuild --
            # see CLAUDE.md, "How a bare session starts (uwsm)".
            package = pkgs.sway.overrideAttrs (old: {
              buildCommand = old.buildCommand + ''
                rm -f $out/share/wayland-sessions/sway.desktop
                cat > $out/share/wayland-sessions/sway.desktop <<'EOF'
                [Desktop Entry]
                Name=Sway
                Comment=An i3-compatible Wayland compositor, started by uwsm
                Exec=${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/sway
                Type=Application
                DesktopNames=sway
                EOF
              '';
            });
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

          # greetd needs a command rather than an entry; same one, so both
          # greeters take the identical path.
          den.desktop.sessionCommands.sway = "${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/sway";

          # System-side half of den.session.anchors above.
          den.desktop.sessionAnchors.sway = "wayland-session@sway.target";

          # XDG portal for screen sharing and file dialogs
          xdg.portal = {
            enable = true;
            wlr = {
              enable = true;
              # xdg-desktop-portal-wlr draws no picker of its own; Firefox delegates
              # screen-sharing entirely to the portal, so without a chooser its
              # getDisplayMedia silently no-ops ("no output found"). screencastChooser
              # (defined above) pops a rofi menu of monitors + windows. (Chrome works
              # without a chooser because it draws its own source picker.)
              settings.screencast = {
                chooser_type = "simple";
                chooser_cmd = "${screencastChooser}/bin/sway-screencast-chooser";
                max_fps = 30;
              };
            };
            extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
          };
        };
      };
  };
}
