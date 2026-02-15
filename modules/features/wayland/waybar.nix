{
  self,
  ...
}:
{
  # Home Manager module for waybar configuration
  flake.homeModules.waybar =
    { pkgs, ... }:
    let
      gpu-script = pkgs.writeShellApplication {
        name = "waybar-gpu";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          export PATH="/run/current-system/sw/bin:$PATH"

          # Try nvidia-smi first, fall back to empty
          if command -v nvidia-smi &>/dev/null; then
            data=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name,power.draw --format=csv,noheader,nounits 2>/dev/null || true)
            if [ -n "$data" ]; then
              usage=$(echo "$data" | cut -d',' -f1 | tr -d ' ')
              temp=$(echo "$data" | cut -d',' -f2 | tr -d ' ')
              mem_used=$(echo "$data" | cut -d',' -f3 | tr -d ' ')
              mem_total=$(echo "$data" | cut -d',' -f4 | tr -d ' ')
              name=$(echo "$data" | cut -d',' -f5 | sed 's/^ //')
              power=$(echo "$data" | cut -d',' -f6 | tr -d ' ')

              text="󰢮 ''${usage}%"
              tooltip="$name"$'\n'"󰢮 ''${usage}%  󰔏 ''${temp}°C"$'\n'"󰍛 ''${mem_used}MiB / ''${mem_total}MiB"$'\n'"󱐋 ''${power} W"

              class=""
              if [ "$usage" -ge 90 ]; then
                class="critical"
              elif [ "$usage" -ge 70 ]; then
                class="warning"
              fi

              jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
                '{text: $text, tooltip: $tooltip, class: $class}'
              exit 0
            fi
          fi

          # No GPU data available
          echo '{"text": "", "tooltip": ""}'
        '';
      };

      intel-gpu-script = pkgs.writeShellApplication {
        name = "waybar-intel-gpu";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          gnused
          jq
        ];
        text = ''
          fallback='{"text": "", "tooltip": ""}'

          # Use the system setcap wrapper which has CAP_PERFMON
          export PATH="/run/wrappers/bin:$PATH"

          if ! command -v intel_gpu_top &>/dev/null; then
            echo "$fallback"
            exit 0
          fi

          # Get GPU name from device listing (e.g. "Intel Alderlake_p (Gen12)")
          gpu_name=$(intel_gpu_top -L 2>/dev/null | grep -i intel | sed 's/^[^ ]* *\([^ ].*[^ ]\) *pci:.*/\1/' | head -n1)
          gpu_name="''${gpu_name:-Intel iGPU}"

          # intel_gpu_top -J streams an incomplete JSON array; capture to a temp
          # file so we preserve the exact bytes, then close the array with ']'.
          tmpfile=$(mktemp)
          trap 'rm -f "$tmpfile"' EXIT
          timeout 2 intel_gpu_top -J -s 500 > "$tmpfile" 2>/dev/null || true

          if [ ! -s "$tmpfile" ]; then
            echo "$fallback"
            exit 0
          fi

          # Extract the last complete JSON object from the array
          sample=$( (cat "$tmpfile"; echo ']') | jq -e 'last(.[])' 2>/dev/null) || true
          if [ -z "$sample" ]; then
            echo "$fallback"
            exit 0
          fi

          # Max busy % across all engines (Render/3D, Video, VideoEnhance, etc.)
          busy=$(echo "$sample" | jq '[.engines[]?.busy] | map(select(. != null)) | if length > 0 then max | round else 0 end')
          freq=$(echo "$sample" | jq '.frequency.actual // 0 | round')
          power=$(echo "$sample" | jq '.power.GPU // empty' 2>/dev/null || echo "")

          text="󰢮 ''${busy}%"
          tooltip="$gpu_name"$'\n'"󰢮 ''${busy}%  󰾆 ''${freq} MHz"
          if [ -n "$power" ]; then
            power_fmt=$(printf "%.1f" "$power")
            tooltip="$tooltip"$'\n'"󱐋 ''${power_fmt} W"
          fi

          class=""
          if [ "$busy" -ge 90 ]; then
            class="critical"
          elif [ "$busy" -ge 70 ]; then
            class="warning"
          fi

          jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
            '{text: $text, tooltip: $tooltip, class: $class}'
        '';
      };

      mkWeatherScript =
        {
          name,
          tempUnit,
          windUnit,
          tempSuffix,
          windSuffix,
        }:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [
            curl
            jq
          ];
          text = ''
            fallback='{"text": "", "tooltip": ""}'

            location=$(curl -sf --max-time 5 "http://ip-api.com/json/?fields=lat,lon,city" || true)
            if [ -z "$location" ]; then
              echo "$fallback"
              exit 0
            fi

            lat=$(echo "$location" | jq -r '.lat')
            lon=$(echo "$location" | jq -r '.lon')
            city=$(echo "$location" | jq -r '.city')

            weather=$(curl -sf --max-time 10 \
              "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m&temperature_unit=${tempUnit}&wind_speed_unit=${windUnit}" || true)
            if [ -z "$weather" ]; then
              echo "$fallback"
              exit 0
            fi

            temp=$(echo "$weather" | jq -r '.current.temperature_2m')
            code=$(echo "$weather" | jq -r '.current.weather_code')
            wind=$(echo "$weather" | jq -r '.current.wind_speed_10m')
            humidity=$(echo "$weather" | jq -r '.current.relative_humidity_2m')

            case $code in
              0)       icon="󰖙"; desc="Clear" ;;
              1)       icon="󰖙"; desc="Mainly clear" ;;
              2)       icon="󰖕"; desc="Partly cloudy" ;;
              3)       icon="󰖐"; desc="Overcast" ;;
              45|48)   icon="󰖑"; desc="Fog" ;;
              51|53|55) icon="󰖗"; desc="Drizzle" ;;
              56|57)   icon="󰖗"; desc="Freezing drizzle" ;;
              61|63|65) icon="󰖖"; desc="Rain" ;;
              66|67)   icon="󰖖"; desc="Freezing rain" ;;
              71|73|75) icon="󰖘"; desc="Snow" ;;
              77)      icon="󰖘"; desc="Snow grains" ;;
              80|81|82) icon="󰖖"; desc="Rain showers" ;;
              85|86)   icon="󰖘"; desc="Snow showers" ;;
              95)      icon="󰖓"; desc="Thunderstorm" ;;
              96|99)   icon="󰖓"; desc="Thunderstorm with hail" ;;
              *)       icon="󰖐"; desc="Unknown" ;;
            esac

            temp_int=$(printf "%.0f" "$temp")
            wind_int=$(printf "%.0f" "$wind")

            text="$icon ''${temp_int}${tempSuffix}"
            tooltip="$desc"$'\n'"$city"$'\n'"󰖙 ''${temp_int}${tempSuffix}  󰖝 ''${wind_int} ${windSuffix}  󰖎 ''${humidity}%"

            jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
          '';
        };

      weather-script = mkWeatherScript {
        name = "waybar-weather";
        tempUnit = "fahrenheit";
        windUnit = "mph";
        tempSuffix = "°F";
        windSuffix = "mph";
      };

      weather-celsius-script = mkWeatherScript {
        name = "waybar-weather-celsius";
        tempUnit = "celsius";
        windUnit = "kmh";
        tempSuffix = "°C";
        windSuffix = "km/h";
      };
    in
    {
      programs.waybar = {
        enable = true;
        systemd.enable = true;
        settings = {
          main = {
            layer = "top";
            position = "top";
            height = 30;

            modules-left = [
              "sway/workspaces"
              "sway/mode"
              "sway/scratchpad"
              "sway/window"
              "mpris"
            ];

            modules-center = [
              "custom/weather-c"
              "clock"
              "custom/weather"
            ];

            modules-right = [
              "cpu"
              "memory"
              "temperature"
              "custom/intel-gpu"
              "custom/nvidia-gpu"
              "wireplumber"
              "backlight"
              "battery"
              "idle_inhibitor"
              "power-profiles-daemon"
              "systemd-failed-units"
              "privacy"
              "gamemode"
              "tray"
            ];

            # Module configurations
            "sway/mode" = {
              format = "<span style=\"italic\">{}</span>";
            };

            "sway/scratchpad" = {
              format = "{icon} {count}";
              show-empty = false;
              format-icons = [
                "󰖲"
                "󰖯"
              ];
              tooltip = true;
              tooltip-format = "{app}: {title}";
            };

            "sway/window" = {
              max-length = 40;
            };

            idle_inhibitor = {
              format = "{icon}";
              format-icons = {
                activated = "󰛊";
                deactivated = "󰾫";
              };
            };

            tray = {
              spacing = 5;
            };

            backlight = {
              format = "{percent}% {icon}";
              format-icons = [
                "󰃞"
                "󰃟"
                "󰃠"
              ];
              on-click = "${pkgs.brightnessctl}/bin/brightnessctl set 100%";
              on-click-middle = "${pkgs.brightnessctl}/bin/brightnessctl set 50%";
              on-click-right = "${pkgs.brightnessctl}/bin/brightnessctl set 10%";
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
              format = "{volume}% {icon}";
              format-muted = "󰝟";
              format-icons = [
                "󰕿"
                "󰖀"
                "󰕾"
              ];
              on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
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
              max-length = 40;
              player-icons = {
                default = "▶";
                mpv = "🎵";
                firefox = "󰈹";
                chromium = "󰊯";
              };
              status-icons = {
                paused = "⏸";
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
              format = "󰻠 {usage}%";
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

            temperature = {
              hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
              input-filename = "temp1_input";
              format = "󰔏 {temperatureC}°C";
              tooltip = true;
              critical-threshold = 80;
              warning-threshold = 60;
            };

            "custom/intel-gpu" = {
              format = "{}";
              return-type = "json";
              exec = "${intel-gpu-script}/bin/waybar-intel-gpu";
              interval = 5;
            };

            "custom/nvidia-gpu" = {
              format = "{}";
              return-type = "json";
              exec = "${gpu-script}/bin/waybar-gpu";
              interval = 5;
            };

            "custom/weather" = {
              format = "{}";
              return-type = "json";
              exec = "${weather-script}/bin/waybar-weather";
              interval = 900;
              on-click = "${weather-script}/bin/waybar-weather";
            };

            "custom/weather-c" = {
              format = "{}";
              return-type = "json";
              exec = "${weather-celsius-script}/bin/waybar-weather-celsius";
              interval = 900;
              on-click = "${weather-celsius-script}/bin/waybar-weather-celsius";
            };

            battery = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{capacity}% ({time}) {icon}";
              format-time = "{H}h {M}m";
              format-charging = "{capacity}% ({time}) 󰂄";
              format-plugged = "{capacity}% 󰚥";
              format-full = "100% 󰁹";
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
        };

        style = ''
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
          #workspaces,
          #mode,
          #scratchpad,
          #window,
          #mpris,
          #systemd-failed-units,
          #privacy,
          #gamemode,
          #custom-weather,
          #custom-weather-c,
          #custom-intel-gpu,
          #custom-nvidia-gpu,
          #idle_inhibitor,
          #power-profiles-daemon,
          #cpu,
          #memory,
          #temperature,
          #backlight,
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
          #temperature:hover,
          #backlight:hover,
          #wireplumber:hover,
          #clock:hover,
          #battery:hover,
          #power-profiles-daemon:hover,
          #idle_inhibitor:hover,
          #custom-weather:hover,
          #custom-weather-c:hover,
          #custom-intel-gpu:hover,
          #custom-nvidia-gpu:hover,
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

          /* --- Sway mode --- */
          #mode {
            color: @red;
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
          #idle_inhibitor.activated {
            color: @lavender;
          }

          #idle_inhibitor.deactivated {
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
          #temperature {
            color: @peach;
          }

          #temperature.critical {
            color: @red;
          }

          /* --- Intel GPU --- */
          #custom-intel-gpu {
            color: @blue;
          }

          #custom-intel-gpu.warning {
            color: @yellow;
          }

          #custom-intel-gpu.critical {
            color: @red;
          }

          /* --- NVIDIA GPU --- */
          #custom-nvidia-gpu {
            color: @green;
          }

          #custom-nvidia-gpu.warning {
            color: @yellow;
          }

          #custom-nvidia-gpu.critical {
            color: @red;
          }

          /* --- Backlight --- */
          #backlight {
            color: @sky;
          }

          /* --- Wireplumber --- */
          #wireplumber {
            color: @pink;
          }

          #wireplumber.muted {
            color: @subtext0;
          }

          /* --- Power profiles --- */
          #power-profiles-daemon {
            color: @mauve;
          }

          /* --- MPRIS --- */
          #mpris {
            color: @mauve;
          }

          /* --- Systemd failed units --- */
          #systemd-failed-units {
            color: @red;
          }

          /* --- Weather --- */
          #custom-weather,
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
      };
    };

  # NixOS module that includes waybar home module
  flake.nixosModules.waybar =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.waybar ];
    };
}
