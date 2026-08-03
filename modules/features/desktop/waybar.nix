{ self, ... }:
{
  # One of the two renderers behind den.desktop.bar. Every module here is
  # instantiated once per output, so an `exec` runs N times on N monitors --
  # see CLAUDE.md, "Choosing a bar", for the measurements and what to do
  # about it.
  #
  # The bar for a bare Wayland session, and only what means the same thing under
  # any compositor. A session contributes its own modules through
  # den.session.bar and gets a config and a unit of its own -- see CLAUDE.md,
  # "One bar per session".
  flake.modules.homeManager.waybar =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (self.lib.barScripts pkgs) gpu weather;

      backlight-script = pkgs.writeShellApplication {
        name = "waybar-backlight";
        runtimeInputs = with pkgs; [
          coreutils
          brightnessctl
          jq
        ];
        text = ''
          # Only show on battery
          on_battery=false
          for ps in /sys/class/power_supply/BAT*; do
            [ -d "$ps" ] || continue
            status=$(cat "$ps/status" 2>/dev/null)
            if [ "$status" = "Discharging" ]; then
              on_battery=true
              break
            fi
          done

          if [ "$on_battery" = false ]; then
            echo '{"text": "", "tooltip": ""}'
            exit 0
          fi

          percent=$(brightnessctl -m | cut -d',' -f4 | tr -d '%')
          if [ "$percent" -lt 34 ]; then
            icon="󰃞"
          elif [ "$percent" -lt 67 ]; then
            icon="󰃟"
          else
            icon="󰃠"
          fi

          jq -nc --arg text "$icon" --arg tooltip "''${percent}%" \
            '{text: $text, tooltip: $tooltip}'
        '';
      };

      temp-script = pkgs.writeShellApplication {
        name = "waybar-temp";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          gnused
          jq
        ];
        text = ''
          # Print a friendly name for an hwmon driver; unknown drivers keep
          # their raw name so a new machine still shows something useful.
          sensor_name() {
            case "$1" in
              coretemp|k10temp|zenpower|cpu_thermal) echo "CPU" ;;
              amdgpu)         echo "AMD GPU" ;;
              nouveau)        echo "NVIDIA GPU" ;;
              i915|xe)        echo "Intel GPU" ;;
              nvme)           echo "NVMe" ;;
              spd5118|jc42)   echo "Memory" ;;
              dell_smm|thinkpad) echo "Board" ;;
              iwlwifi*)       echo "WiFi" ;;
              acpitz)         echo "ACPI" ;;
              *)              echo "$1" ;;
            esac
          }

          # CPU sensors come from different drivers per platform: coretemp on
          # Intel, k10temp/zenpower on AMD, cpu_thermal on ARM. acpitz is the
          # last resort — it reports a board sensor rather than the die.
          cpu_hwmon=""
          for driver in coretemp k10temp zenpower cpu_thermal acpitz; do
            for hwmon in /sys/class/hwmon/hwmon*; do
              [ -r "$hwmon/name" ] || continue
              if [ "$(cat "$hwmon/name")" = "$driver" ]; then
                cpu_hwmon="$hwmon"
                break 2
              fi
            done
          done

          # The bar shows the die/package reading; per-core sensors and every
          # other device go in the tooltip.
          cpu_input=""
          for preferred in Tdie Package Tctl CPU; do
            for label_file in "$cpu_hwmon"/temp*_label; do
              [ -f "$label_file" ] || continue
              label=$(cat "$label_file")
              # Prefix match, so "Package id 0" matches "Package"
              if [ "''${label#"$preferred"}" != "$label" ]; then
                cpu_input="''${label_file%_label}_input"
                break 2
              fi
            done
          done
          # Unlabeled drivers (acpitz, cpu_thermal) expose a single temp1_input
          if [ -z "$cpu_input" ] && [ -n "$cpu_hwmon" ]; then
            cpu_input="$cpu_hwmon/temp1_input"
          fi

          if [ -z "$cpu_input" ] || [ ! -r "$cpu_input" ]; then
            echo '{"text": "󰔏 N/A", "tooltip": "No CPU temperature sensor found"}'
            exit 0
          fi

          cpu_c=$(( $(cat "$cpu_input") / 1000 ))
          tooltip="CPU: ''${cpu_c}°C"

          # Remaining sensors on the CPU chip: per-core on Intel, Tccd* on AMD
          for label_file in "$cpu_hwmon"/temp*_label; do
            [ -f "$label_file" ] || continue
            input_file="''${label_file%_label}_input"
            [ "$input_file" = "$cpu_input" ] && continue
            [ -r "$input_file" ] || continue
            tooltip="$tooltip"$'\n'"  $(cat "$label_file"): $(( $(cat "$input_file") / 1000 ))°C"
          done

          # Every other hwmon device that reports a temperature
          for hwmon in /sys/class/hwmon/hwmon*; do
            [ "$hwmon" = "$cpu_hwmon" ] && continue
            [ -r "$hwmon/name" ] || continue
            device=$(sensor_name "$(cat "$hwmon/name")")
            for input_file in "$hwmon"/temp*_input; do
              [ -r "$input_file" ] || continue
              label_file="''${input_file%_input}_label"
              if [ -f "$label_file" ]; then
                name="$device $(cat "$label_file")"
              else
                name="$device"
              fi
              tooltip="$tooltip"$'\n'"$name: $(( $(cat "$input_file") / 1000 ))°C"
            done
          done

          # Thermal zones cover sensors with no hwmon entry (WiFi, skin, charger)
          for zone_dir in /sys/class/thermal/thermal_zone*; do
            [ -r "$zone_dir/type" ] || continue
            type=$(cat "$zone_dir/type")
            # Skip zones already reported through hwmon and generic sensors
            case "$type" in
              acpitz|x86_pkg_temp|TCPU|TCPU_PCI|INT3400*|SEN*) continue ;;
            esac
            case "$type" in
              TSKN) name="Skin" ;;
              TMEM) name="Memory" ;;
              CHRG) name="Charger" ;;
              *)    name=$(sensor_name "$type") ;;
            esac
            tooltip="$tooltip"$'\n'"$name: $(( $(cat "$zone_dir/temp") / 1000 ))°C"
          done

          # Determine warning class
          class=""
          if [ "$cpu_c" -ge 80 ]; then
            class="critical"
          elif [ "$cpu_c" -ge 60 ]; then
            class="warning"
          fi

          jq -nc --arg text "󰔏 ''${cpu_c}°C" --arg tooltip "$tooltip" --arg class "$class" \
            '{text: $text, tooltip: $tooltip, class: $class}'
        '';
      };

      jsonFormat = pkgs.formats.json { };

      # Everything below reads the same under any compositor. What does not --
      # workspaces, window title, whatever else speaks the compositor's IPC --
      # arrives per session in den.session.bar.
      sharedBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-center = [
          "custom/weather-c"
          "systemd-failed-units"
          "privacy"
          "gamemode"
          "clock"
          "custom/weather-f"
        ];

        modules-right = [
          "cpu"
          "memory"
          "custom/temp"
          "custom/gpu"
          "wireplumber"
          "battery"
          "custom/backlight"
          "custom/idle-inhibitor"
          "power-profiles-daemon"
          "tray"
        ];

        "custom/idle-inhibitor" = {
          exec = pkgs.writeShellScript "waybar-idle-inhibitor" ''
            if ${pkgs.systemd}/bin/systemctl --user is-active swayidle.service &>/dev/null; then
              echo '{"text":"󰾫","tooltip":"Idle inhibitor: inactive","class":"deactivated"}'
            else
              echo '{"text":"󰛊","tooltip":"Idle inhibitor: active","class":"activated"}'
            fi
          '';
          on-click = pkgs.writeShellScript "waybar-idle-inhibitor-toggle" ''
            if ${pkgs.systemd}/bin/systemctl --user is-active swayidle.service &>/dev/null; then
              ${pkgs.systemd}/bin/systemctl --user stop swayidle.service
            else
              ${pkgs.systemd}/bin/systemctl --user start swayidle.service
            fi
          '';
          return-type = "json";
          interval = 5;
        };

        tray = {
          spacing = 5;
        };

        "custom/backlight" = {
          exec = "${backlight-script}/bin/waybar-backlight";
          format = "{}";
          return-type = "json";
          interval = 5;
          on-click = "${pkgs.brightnessctl}/bin/brightnessctl set 100%";
          on-click-middle = "${pkgs.brightnessctl}/bin/brightnessctl set 50%";
          on-click-right = "${pkgs.brightnessctl}/bin/brightnessctl set 10%";
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
          on-scroll-down = pkgs.writeShellScript "backlight-down" ''
            max=$(${pkgs.brightnessctl}/bin/brightnessctl max)
            min=$((max * 5 / 100))
            current=$(${pkgs.brightnessctl}/bin/brightnessctl get)
            step=$((max * 5 / 100))
            target=$((current - step))
            if [ "$target" -lt "$min" ]; then
              target=$min
            fi
            ${pkgs.brightnessctl}/bin/brightnessctl set "$target"
          '';
        };

        power-profiles-daemon = {
          format = "{icon}";
          tooltip-format = "Power profile: {profile}\nDriver: {driver}";
          tooltip = true;
          format-icons = {
            default = "󰾅";
            performance = "󰓅";
            balanced = "󰾅";
            power-saver = "󰾆";
          };
        };

        wireplumber = {
          max-volume = 125;
          format = "{volume}% {icon}";
          format-muted = "󰝟";
          format-icons = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
          on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume -l 1.25 @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        };

        clock = {
          format = "󰥔 {:%I:%M %p}";
          format-alt = "󰃭 {:%A, %B %d, %Y (%r)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#cdd6f4'><b>{}</b></span>";
              days = "<span color='#cdd6f4'><b>{}</b></span>";
              weeks = "<span color='#94e2d5'><b>W{}</b></span>";
              weekdays = "<span color='#f9e2af'><b>{}</b></span>";
              today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
            };
          };
          actions = {
            on-click-right = "mode";
            on-click-forward = "tz_up";
            on-click-backward = "tz_down";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };

        mpris = {
          format = "{player_icon} {title} - {artist}";
          format-paused = "{status_icon} {title} - {artist}";
          max-length = 45;
          player-icons = {
            default = "󰐊";
            mpv = "󰎁";
            tidal-hifi = "󰎆";
            firefox = "󰈹";
            chromium = "󰊯";
          };
          status-icons = {
            paused = "󰏤";
          };
          on-click = "${pkgs.playerctl}/bin/playerctl play-pause";
          on-click-middle = "${pkgs.playerctl}/bin/playerctl previous";
          on-click-right = "${pkgs.playerctl}/bin/playerctl next";
          on-scroll-up = "${pkgs.playerctl}/bin/playerctl volume 0.05+";
          on-scroll-down = "${pkgs.playerctl}/bin/playerctl volume 0.05-";
        };

        systemd-failed-units = {
          hide-on-ok = true;
          format = "󰒏 {nr_failed}";
          format-ok = "";
          system = true;
          user = true;
        };

        cpu = {
          # Chip-with-pins, not the nf-md cpu glyph: that one is a
          # gear-in-square indistinguishable from #memory's at 13px, and the
          # two modules are adjacent.
          format = "󰘚 {usage}%";
          tooltip = true;
          states = {
            warning = 70;
            critical = 90;
          };
        };

        memory = {
          format = "󰍛 {percentage}%";
          tooltip-format = "{used:0.1f}GiB / {total:0.1f}GiB";
          states = {
            warning = 70;
            critical = 90;
          };
        };

        "custom/temp" = {
          format = "{}";
          return-type = "json";
          exec = "${temp-script}/bin/waybar-temp";
          interval = 5;
        };

        "custom/gpu" = {
          format = "{}";
          return-type = "json";
          exec = lib.getExe gpu;
          interval = 5;
        };

        "custom/weather-f" = {
          format = "{}";
          return-type = "json";
          exec = "${lib.getExe weather} f";
          interval = 900;
          on-click = "${lib.getExe weather} f";
        };

        "custom/weather-c" = {
          format = "{}";
          return-type = "json";
          exec = "${lib.getExe weather} c";
          interval = 900;
          on-click = "${lib.getExe weather} c";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon}";
          format-time = "{H}h {M}m";
          format-charging = "";
          format-plugged = "";
          format-full = "";
          tooltip-format = "{capacity}% — {timeTo}";
          format-icons = [
            "󰂎"
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
        };
      };

      # One style for every bar, referenced by the units below as well as
      # written to ~/.config/waybar/style.css by programs.waybar.
      styleFile = pkgs.writeText "waybar-style.css" ''
        /* === Catppuccin Mocha Flat Minimal === */
        @define-color base #1e1e2e;
        @define-color mantle #181825;
        @define-color surface0 #313244;
        @define-color text #cdd6f4;
        @define-color subtext0 #a6adc8;
        @define-color blue #89b4fa;
        @define-color lavender #b4befe;
        @define-color green #a6e3a1;
        @define-color yellow #f9e2af;
        @define-color red #f38ba8;
        @define-color peach #fab387;
        @define-color mauve #cba6f7;
        @define-color teal #94e2d5;
        @define-color sky #89dceb;
        @define-color pink #f5c2e7;

        * {
          font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
          font-size: 13px;
          min-height: 0;
        }

        window#waybar {
          background-color: rgba(30, 30, 46, 0.85);
          color: @text;
        }

        tooltip {
          background-color: @mantle;
          border: 1px solid @surface0;
          border-radius: 8px;
          color: @text;
        }

        tooltip label {
          color: @text;
        }

        /* --- Global module defaults --- */
        /* #workspaces, #mode, #scratchpad and #window are the ids the
           per-session modules take, whichever compositor supplies them. */
        #workspaces,
        #mode,
        #scratchpad,
        #window,
        #mpris,
        #systemd-failed-units,
        #privacy,
        #gamemode,
        #custom-weather-f,
        #custom-weather-c,
        #custom-gpu,
        #custom-idle-inhibitor,
        #power-profiles-daemon,
        #cpu,
        #memory,
        #custom-temp,
        #custom-backlight,
        #wireplumber,
        #clock,
        #battery,
        #tray {
          padding: 0 8px;
          margin: 0 2px;
          color: @text;
          transition: background-color 200ms ease;
        }

        /* Hover effect */
        #cpu:hover,
        #memory:hover,
        #custom-temp:hover,
        #custom-backlight:hover,
        #wireplumber:hover,
        #clock:hover,
        #battery:hover,
        #power-profiles-daemon:hover,
        #custom-idle-inhibitor:hover,
        #custom-weather-f:hover,
        #custom-weather-c:hover,
        #custom-gpu:hover,
        #mpris:hover,
        #tray:hover {
          background-color: @surface0;
          border-radius: 4px;
        }

        /* --- Workspaces --- */
        #workspaces button {
          padding: 0 6px;
          color: @subtext0;
          border: none;
          border-radius: 0;
          background: transparent;
          transition: all 200ms ease;
        }

        #workspaces button:hover {
          background-color: @surface0;
          border-radius: 4px;
        }

        #workspaces button.focused {
          color: @blue;
          border-bottom: 2px solid @blue;
        }

        #workspaces button.active {
          color: @blue;
          border-bottom: 2px solid @blue;
        }

        #workspaces button.urgent {
          color: @red;
        }

        /* --- Mode --- */
        /* Peach, not red: a mode is a state you are in, not something wrong.
           @red and @yellow are alert-only across this bar. */
        #mode {
          color: @peach;
          font-weight: bold;
        }

        /* --- Scratchpad --- */
        #scratchpad {
          color: @lavender;
        }

        /* --- Window title --- */
        #window {
          color: @subtext0;
          font-style: italic;
        }

        /* --- Clock --- */
        #clock {
          color: @lavender;
        }

        /* --- Idle inhibitor --- */
        #custom-idle-inhibitor.activated {
          color: @lavender;
        }

        #custom-idle-inhibitor.deactivated {
          color: @subtext0;
        }

        /* --- Battery --- */
        #battery {
          color: @green;
        }

        #battery.charging {
          color: @green;
        }

        #battery.warning:not(.charging) {
          color: @yellow;
        }

        #battery.critical:not(.charging) {
          color: @red;
        }

        /* --- CPU --- */
        #cpu.warning {
          color: @yellow;
        }

        #cpu.critical {
          color: @red;
        }

        /* --- Memory --- */
        #memory.warning {
          color: @yellow;
        }

        #memory.critical {
          color: @red;
        }

        /* --- Temperature --- */
        /* Plain until it matters, like #cpu and #memory -- the three load
           metrics read the same way. The script emits `warning` at 60C, which
           had no rule here, so 60-79C was indistinguishable from idle. */
        #custom-temp.warning {
          color: @yellow;
        }

        #custom-temp.critical {
          color: @red;
        }

        /* --- GPU --- */
        /* Text colour is vendor identity -- green NVIDIA, blue Intel, peach AMD
           -- written by the widget as Pango markup, which wins over any colour
           set here. So load signals through an underline on a channel of its
           own, and no vendor reading can be mistaken for an alert. The
           transparent border keeps the label from shifting when one appears. */
        #custom-gpu {
          border-bottom: 2px solid transparent;
        }

        #custom-gpu.warning {
          border-bottom: 2px solid @yellow;
        }

        #custom-gpu.critical {
          border-bottom: 2px solid @red;
        }

        /* --- Backlight --- */
        #custom-backlight {
          color: @sky;
        }

        /* --- Wireplumber --- */
        /* Mauve rather than pink: this sits immediately right of #custom-gpu,
           whose AMD reading is peach. */
        #wireplumber {
          color: @mauve;
        }

        #wireplumber.muted {
          color: @subtext0;
        }

        /* --- Power profiles --- */
        #power-profiles-daemon {
          color: @teal;
        }

        /* --- MPRIS --- */
        #mpris {
          color: @mauve;
        }

        /* --- Systemd failed units --- */
        #systemd-failed-units {
          color: @red;
        }

        /* --- Privacy --- */
        /* Only ever visible while the mic or camera is live, which is the one
           thing on this bar you most want to notice. */
        #privacy {
          color: @red;
        }

        /* --- GameMode --- */
        #gamemode {
          color: @pink;
        }

        /* --- Weather --- */
        #custom-weather-f,
        #custom-weather-c {
          color: @teal;
        }

        /* --- Tray --- */
        #tray > .passive {
          -gtk-icon-effect: dim;
        }

        #tray > .needs-attention {
          -gtk-icon-effect: highlight;
          color: @yellow;
        }
      '';

      # A bar with no anchor has nothing to start it; the assertion below names
      # it rather than letting the lookup throw.
      bars = lib.filterAttrs (id: _: config.den.session.anchors ? ${id}) config.den.session.bar;

      barFiles = lib.mapAttrs (
        id: bar:
        jsonFormat.generate "waybar-${id}.json" (
          sharedBar // bar.settings // { modules-left = bar.modules ++ [ "mpris" ]; }
        )
      ) bars;
    in
    {
      key = "den:homeManager.waybar";
      imports = [ self.modules.homeManager.session-options ];

      assertions = lib.mapAttrsToList (id: _: {
        assertion = config.den.session.anchors ? ${id};
        message = "den.session.bar.${id} has no den.session.anchors.${id}, so nothing would start its bar";
      }) config.den.session.bar;

      programs.waybar = {
        enable = bars != { };
        # Home Manager writes one config and one unit; this bar needs a pair per
        # session, generated below. `settings` stays at its default so nothing
        # lands in waybar/config.
        systemd.enable = false;
        style = styleFile;
      };

      # Not read by the units, which name the store path -- these are for
      # running `waybar -c ~/.config/waybar/<session>.json` by hand.
      xdg.configFile = lib.mapAttrs' (
        id: file: lib.nameValuePair "waybar/${id}.json" { source = file; }
      ) barFiles;

      systemd.user.services = lib.mapAttrs' (
        id: file:
        let
          anchor = config.den.session.anchors.${id};
        in
        lib.nameValuePair "waybar-${id}" {
          Unit = {
            Description = "Waybar for the ${id} session";
            Documentation = "https://github.com/Alexays/Waybar/wiki";
            PartOf = [ anchor ];
            After = [ anchor ];
            ConditionEnvironment = "WAYLAND_DISPLAY";
            X-Reload-Triggers = [
              "${file}"
              "${styleFile}"
            ];
          };
          Service = {
            ExecStart = "${lib.getExe config.programs.waybar.package} -c ${file} -s ${styleFile}";
            ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR2 $MAINPID";
            KillMode = "mixed";
            Restart = "on-failure";
          };
          Install.WantedBy = [ anchor ];
        }
      ) barFiles;
    };
}
