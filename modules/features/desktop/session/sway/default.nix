{
  self,
  ...
}:
let
  # Modifier key
  mod = "Mod4";
in
{
  # Sway, and only what names Sway. Everything a bare Wayland session needs but
  # any compositor could provide -- notifications, launcher, locker, idle,
  # outputs, keyring, tray applets -- lives in session/wayland.nix, which both
  # halves below import.
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
        # Every user on the host receives this, because every user may log into
        # Sway. What keeps it out of their GNOME session is the anchor below,
        # not the absence of this module -- waybar and kanshi reached every user
        # once before and did land in GNOME, since they were bound to
        # graphical-session.target rather than to a session.
        imports = with self.modules.homeManager; [
          # The companion stack, and the den.session options set below.
          session-wayland
          session-options
          # Declares the `monitors` option read above -- imported here rather
          # than left to whoever pulls this module in.
          monitors
          waybar
          # dictation
        ];

        # uwsm generates this target from the compositor id, which it takes from
        # the basename of the binary it starts -- `uwsm start -n` reports
        # "Selected compositor ID: sway". So it is what "a Sway session is
        # running" means for this user, and session/wayland.nix hangs the
        # companions off it. The key stays "sway" because that is what the
        # session announces in XDG_CURRENT_DESKTOP, which is what makes
        # sway-mimeapps.list work.
        den.session.anchors.sway = "wayland-session@sway.target";

        wayland.windowManager.sway = {
          enable = true;

          # Config only, no binary. uwsm starts
          # /run/current-system/sw/bin/sway by absolute path, so the wrapper
          # carrying the session environment has to be the system one -- Home
          # Manager's own wrapper would simply never run. Upstream documents
          # `package = null` for exactly this pairing ("if you want to use the
          # NixOS Sway module"), and it also turns off checkConfig, which needs
          # a binary. wrapperFeatures, extraOptions and extraSessionCommands
          # therefore live on programs.sway below.
          #
          # This also settles an ambiguity that predates uwsm: both modules were
          # building a wrapper, they differed, and which one a session got came
          # down to whether /etc/profiles/per-user came before
          # /run/current-system/sw in PATH.
          package = null;

          # uwsm owns session startup: wayland-wm@sway.service runs the
          # compositor and wayland-session@sway.target is the anchor. Home
          # Manager must not also generate sway-session.target and race to start
          # it. `uwsm finalize` below replaces its environment import.
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

            # Startup commands. `uwsm finalize` comes first and is not optional:
            # wayland-wm@sway.service is Type=notify, so without it the unit
            # never reports ready and systemd kills the session after 30s.
            #
            # It exports WAYLAND_DISPLAY and DISPLAY by itself; everything named
            # here is a variable something outside the compositor's process tree
            # needs. Systemd user services and dbus-activated apps are not sway's
            # children -- they read the systemd/dbus user environment, which only
            # ever receives what is exported to it. SWAYSOCK is how waybar finds
            # the compositor at all; the toolkit variables are set by
            # programs.sway.extraSessionCommands and would otherwise stop at the
            # process boundary. (WLR_NO_HARDWARE_CURSORS is read by sway itself,
            # so it is deliberately not here.)
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

        # Blanking the outputs is the compositor's own call, so it is the one
        # swayidle timeout that cannot be shared; session/wayland.nix supplies
        # the lock and suspend ones and the list definitions merge.
        services.swayidle.timeouts = [
          {
            timeout = 360;
            command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
            resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
          }
        ];

        # Sway's own portal preferences. session/wayland.nix sets `enable`, the
        # common fallback and the gtk backend; both options merge, so this only
        # adds what is specific to wlroots screen capture.
        xdg.portal = {
          config.sway = {
            default = [ "gtk" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
          };
          extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
        };

        # grimshot drives sway's own screenshot IPC, so it is the one tool here
        # that no other session could use. waybar comes from programs.waybar.
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
        # Screen-share picker for xdg-desktop-portal-wlr. wlroots can only capture
        # a whole monitor or a whole window (never an arbitrary region), so this
        # lists both in a rofi menu and returns the exact token xdpw expects:
        # "Monitor: <output>" or "Window: <ext-foreign-toplevel-list-v1 id>".
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

            # Active monitors. Both displays are often the same model, so the label
            # carries resolution, left/right position, orientation and a ★ on the
            # focused output. The token returned to xdpw stays "Monitor: <name>".
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
          # The system half of the companion stack (swaylock PAM, keyring,
          # polkit, the Bluetooth applet). It gates itself on
          # den.desktop.sessionAnchors, which the mkIf below contributes to, so
          # it stays inert on a host that never selected a bare session --
          # `imports` is not covered by that mkIf.
          session-wayland
        ];

        config = lib.mkIf (lib.elem "sway" config.den.desktop.environments) {
          # `programs.sway.enable` registers the plain "Sway" session with
          # services.displayManager.sessionPackages, which is the only thing a
          # login manager needs to offer it. No greeter is configured here.
          #
          # This wrapper is now the only sway anyone starts (Home Manager sets
          # `package = null`), so the session environment lives here. These
          # exports reach sway and every process it spawns; anything outside
          # that tree gets them through `uwsm finalize` in the Home Manager half.
          programs.sway = {
            enable = true;
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

          # Wrap the compositor in a systemd user session. Sway on its own gives
          # you a compositor and nothing else -- no session target to bind
          # helpers to, no XDG autostart, no environment in the user manager --
          # and every bare compositor solves that differently or not at all
          # (niri ships units, mangowc ships nothing). uwsm makes it one answer:
          # wayland-session@<id>.target for all of them.
          #
          # This registers a *second* entry, "Sway (UWSM)", alongside the plain
          # one above. Both are kept on purpose while this is new: if a uwsm
          # session fails to come up, the greeter still offers the session that
          # worked before.
          programs.uwsm = {
            enable = true;
            waylandCompositors.sway = {
              prettyName = "Sway";
              comment = "Sway compositor managed by UWSM";
              # Deliberately the system path rather than lib.getExe: uwsm has to
              # start the same sway the rest of the system has, and this is the
              # wrapper configured above.
              binPath = "/run/current-system/sw/bin/sway";
            };
          };

          # greetd ignores services.displayManager.defaultSession, so it needs a
          # real command per session it might start. Both entries get one; the
          # uwsm command is what nixpkgs writes into the desktop entry.
          den.desktop.sessionCommands = {
            sway = "sway";
            "sway-uwsm" = "${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/sway";
          };

          # Sway ships no bar, notifier, locker or file manager, so it needs the
          # companion stack; naming the unit that stands for a running Sway
          # session is what lets system-level user units attach to it and only to
          # it. The per-user half is den.session.anchors above.
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
