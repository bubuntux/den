{ self, ... }:
{
  # The other renderer behind den.desktop.bar. Unlike waybar this is *one* bar
  # for every session the host installs: ironbar picks its compositor backend
  # at startup from SWAYSOCK / HYPRLAND_INSTANCE_SIGNATURE / NIRI_SOCKET, so
  # `workspaces` needs no per-session variant. What that costs, and why the
  # readings still come from the shared scripts, is in CLAUDE.md,
  # "Choosing a bar".
  flake.modules.homeManager.ironbar =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (self.lib.barScripts pkgs) gpu weather;

      jsonFormat = pkgs.formats.json { };
      ironbar = lib.getExe pkgs.ironbar;

      # The unit every Wayland companion follows, which is what a bar serving
      # all of them wants. session/wayland.nix points this at den-session.target.
      sessionTarget = config.wayland.systemd.target;

      installedSessions = lib.attrNames config.den.session.anchors;

      # Installed either way; only the bar the session starts is wanted by the
      # target, so the other can be reached with `systemctl --user start`.
      active = config.den.session.activeBar == "ironbar";

      # Ironbar's own support matrix, from its docs. A module goes in only when
      # every session on this host can back it: one config serves them all, and
      # a module whose compositor is missing is dropped with an error in the
      # journal rather than a message on screen.
      supportedBy = {
        workspaces = [
          "sway"
          "hyprland"
          "niri"
        ];
        bindmode = [
          "sway"
          "hyprland"
        ];
      };
      whereSupported =
        module:
        lib.optional (lib.all (id: lib.elem id supportedBy.${module.type}) installedSessions) module;

      # Everything the native modules cannot report, produced once and pushed
      # to every bar as an ironvar. This is the whole reason a second renderer
      # is worth having: `ironbar var set` is one process for N monitors, where
      # a script module is N processes.
      #
      # A producer hangs off the bar rather than the session, so the session
      # wants one unit and `systemctl --user start ironbar` brings the lot.
      varsService =
        {
          name,
          interval,
          packages ? [ ],
          body,
        }:
        {
          Unit = {
            Description = "Ironbar values for ${name}";
            PartOf = [ "ironbar.service" ];
            After = [ "ironbar.service" ];
          };
          Service = {
            ExecStart = lib.getExe (
              pkgs.writeShellApplication {
                name = "ironbar-${name}";
                runtimeInputs = [ pkgs.jq ] ++ packages;
                text = ''
                  # Tolerant on purpose: a producer outlives any one bar
                  # process, and at session start it can beat the daemon to
                  # the socket.
                  set_var() { ${ironbar} var set "$1" "$2" >/dev/null || true; }
                  while :; do
                    ${body}
                    sleep ${toString interval}
                  done
                '';
              }
            );
            Restart = "on-failure";
          };
          Install.WantedBy = [ "ironbar.service" ];
        };

      settings = {
        position = "top";
        height = 30;

        ironvar_defaults = {
          gpu = "";
          gpu_tooltip = "";
          alerts = "";
          power_profile = "";
          weather_c = "";
          weather_f = "";
          weather_tooltip = "";
        };

        start =
          whereSupported { type = "workspaces"; }
          ++ whereSupported { type = "bindmode"; }
          ++ [
            {
              type = "focused";
              truncate = {
                mode = "end";
                max_length = 45;
              };
            }
            {
              type = "music";
              truncate = {
                mode = "end";
                max_length = 45;
              };
            }
          ];

        center = [
          {
            type = "label";
            name = "weather-c";
            label = "#weather_c";
            tooltip = "#weather_tooltip";
            show_if = "#weather_c";
          }
          {
            type = "label";
            name = "alerts";
            label = "#alerts";
            show_if = "#alerts";
          }
          {
            type = "clock";
            format = "%I:%M %p";
            format_popup = "%A, %B %d, %Y (%r)";
            show_week_numbers = true;
          }
          {
            type = "label";
            name = "weather-f";
            label = "#weather_f";
            tooltip = "#weather_tooltip";
            show_if = "#weather_f";
          }
        ];

        end = [
          {
            type = "sys_info";
            # temp_c with no sensor reduces with `max`, so this is the hottest
            # sensor on the board rather than waybar's package reading.
            format = [
              "󰘚 {cpu_percent}%"
              "󰍛 {memory_percent}%"
              "󰔏 {temp_c}°C"
            ];
            interval = {
              cpu = 5;
              memory = 5;
              temps = 5;
            };
          }
          {
            type = "label";
            name = "gpu";
            label = "#gpu";
            tooltip = "#gpu_tooltip";
            show_if = "#gpu";
          }
          { type = "volume"; }
          { type = "battery"; }
          { type = "brightness"; }
          { type = "inhibit"; }
          {
            type = "label";
            name = "power-profile";
            label = "#power_profile";
            show_if = "#power_profile";
          }
          { type = "tray"; }
        ];
      };

      configFile = jsonFormat.generate "ironbar-config.json" settings;
    in
    {
      key = "den:homeManager.ironbar";
      imports = [ self.modules.homeManager.session-options ];

      home.packages = [ pkgs.ironbar ];

      # For running the bar by hand; the unit names the store path.
      xdg.configFile."ironbar/config.json".source = configFile;

      systemd.user.services = {
        ironbar = {
          Unit = {
            Description = "Ironbar";
            Documentation = "https://github.com/JakeStanger/ironbar/wiki";
            PartOf = [ sessionTarget ];
            After = [ sessionTarget ];
            ConditionEnvironment = "WAYLAND_DISPLAY";
            X-Reload-Triggers = [ "${configFile}" ];
          };
          Service = {
            # `minimal` is one of ironbar's two built-in stylesheets. Naming it
            # is not the same as omitting -t: with no theme ironbar looks for a
            # style.css next to the config, logs an error when the store path
            # has none, and falls back here anyway -- which would also fail
            # --validate-config.
            ExecStart = "${ironbar} -c ${configFile} -t minimal";
            Restart = "on-failure";
          };
          Install.WantedBy = lib.optional active sessionTarget;
        };

        ironbar-vars = varsService {
          name = "vars";
          interval = 5;
          packages = with pkgs; [
            coreutils
            systemd
            power-profiles-daemon
          ];
          body = ''
            snapshot=$(${lib.getExe gpu})
            set_var gpu "$(jq -r .text <<<"$snapshot")"
            set_var gpu_tooltip "$(jq -r .tooltip <<<"$snapshot")"

            failed=$(systemctl list-units --failed --output=json | jq length)
            failed=$((failed + $(systemctl --user list-units --failed --output=json | jq length)))
            if [ "$failed" -gt 0 ]; then set_var alerts "󰒏 $failed"; else set_var alerts ""; fi

            profile=$(powerprofilesctl get 2>/dev/null || true)
            case "$profile" in
              performance) set_var power_profile "󰓅" ;;
              balanced)    set_var power_profile "󰾅" ;;
              power-saver) set_var power_profile "󰾆" ;;
              *)           set_var power_profile "" ;;
            esac
          '';
        };

        # Its own unit rather than a slow branch of the one above: the fetch
        # has a 10s curl timeout, and the GPU reading must not wait on it.
        ironbar-weather = varsService {
          name = "weather";
          interval = 900;
          body = ''
            set_var weather_c "$(${lib.getExe weather} c | jq -r .text)"
            set_var weather_f "$(${lib.getExe weather} f | jq -r .text)"
            set_var weather_tooltip "$(${lib.getExe weather} c | jq -r .tooltip)"
          '';
        };
      };
    };
}
