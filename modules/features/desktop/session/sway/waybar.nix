_: {
  # TODO: Consider replacing Waybar with Ironbar or similar bar that shares
  # module state across monitors. Currently each module (scripts, polling, etc.)
  # runs independently per monitor, tripling resource usage on a 3-monitor setup.

  # The bar for the Sway session, imported by homeManager.sway so it lands only
  # on users of that session -- its modules are sway/workspaces, sway/mode,
  # sway/scratchpad, sway/window and a swayidle toggle, none of which mean
  # anything under another desktop.
  flake.modules.homeManager.waybar =
    { pkgs, ... }:
    let
      # Catppuccin Mocha, mirroring the @define-color block in `style` below.
      # Pango markup cannot reference CSS colour names, so the widget needs the
      # literals. Colour here means vendor and nothing else -- load is an
      # underline, see the #custom-gpu rules. AMD is peach rather than the red
      # its brand suggests: @red is what every alert in this bar uses.
      gpuVendorColors = {
        nvidia = "#a6e3a1"; # @green
        intel = "#89b4fa"; # @blue
        amd = "#fab387"; # @peach
        unknown = "#cdd6f4"; # @text
      };

      # One widget for however many GPUs the host has, of whatever make. nvtop
      # covers the mesa vendors in a single JSON shape, so an APU and a hybrid
      # laptop share one code path; NVIDIA is the one exception, and it is
      # nvidia-smi rather than nvtop's own backend because that backend builds
      # against cudatoolkit -- a 3.9 GiB, largely uncached closure for numbers
      # the driver's own tool already reports.
      gpu-script = pkgs.writeShellApplication {
        name = "waybar-gpu";
        runtimeInputs = with pkgs; [
          jq
          (nvtopPackages.full.override { nvidia = false; })
        ];
        text = ''
          nvtop_gpus='[]'
          if snapshot=$(nvtop -s 2>/dev/null) && [ -n "$snapshot" ]; then
            # .processes is every GPU client with its full cmdline. Not for a bar.
            nvtop_gpus=$(jq -c 'map(del(.processes))' <<<"$snapshot") || nvtop_gpus='[]'
          fi

          # nvidia-smi comes from the driver, not a package, so it is only ever
          # on PATH via the system profile.
          export PATH="/run/current-system/sw/bin:$PATH"
          nvidia_csv=""
          if command -v nvidia-smi >/dev/null 2>&1; then
            nvidia_csv=$(nvidia-smi \
              --query-gpu=name,utilization.gpu,temperature.gpu,power.draw,memory.used,memory.total \
              --format=csv,noheader,nounits 2>/dev/null) || nvidia_csv=""
          fi

          jq -nc --argjson nvtop "$nvtop_gpus" --arg nvidia "$nvidia_csv" \
                 --argjson colors '${builtins.toJSON gpuVendorColors}' '
            # nvtop reports every value unit-suffixed ("47C", "5W"), and "N/A"
            # wherever a backend has no such sensor -- Intel reports no power.
            def num: (tostring | capture("(?<n>[0-9]+(\\.[0-9]+)?)") | .n | tonumber) // 0;
            def mib: (. / 1048576 | floor);

            # The reported name is all there is to go on: nvtop says "AMD Radeon
            # 780M Graphics" or "Intel Alderlake_p", nvidia-smi always leads with
            # "NVIDIA". Checked most- to least-specific.
            def vendor: ascii_downcase
              | if   test("nvidia|geforce|quadro|tesla") then "nvidia"
                elif test("intel")                       then "intel"
                elif test("amd|radeon")                  then "amd"
                else "unknown" end;

            ($nvtop | map({
              name:  (.device_name // "GPU"),
              util:  (.gpu_util   | num),
              temp:  (.temp       | num),
              power: (.power_draw | num),
              used:  (.mem_used   | num),
              total: (.mem_total  | num),
            }))
            # nvidia-smi reports memory in MiB, where nvtop reports bytes.
            + ($nvidia | split("\n") | map(select(length > 0) | split(", ") | {
              name:  .[0],
              util:  (.[1] | num),
              temp:  (.[2] | num),
              power: (.[3] | num),
              used:  ((.[4] | num) * 1048576),
              total: ((.[5] | num) * 1048576),
            }))
            | map(. + { color: ($colors[.name | vendor] // $colors.unknown) }) as $gpus
            | ($gpus | map(.util) | max // 0) as $peak
            | if $peak == 0 then { text: "", tooltip: "" } else {
                # Markup, so device names have to be escaped -- waybar renders
                # both the label and the tooltip through Pango.
                # The icon goes inside the span, so each GPU is one unit in one
                # colour. A single shared icon would have to take one vendor
                # colour and would then contradict the reading beside it.
                # (No apostrophes in here: the jq program is shell single-quoted.)
                text: ($gpus
                  | map("<span color=\"\(.color)\">󰢮 \(.util)%</span>")
                  | join(" ")),
                tooltip: ($gpus | map(
                  "<span color=\"\(.color)\">\(.name | @html)</span>"
                  + "\n󰢮 \(.util)%  󰔏 \(.temp)°C"
                  + (if .power > 0 then "  󱐋 \(.power) W" else "" end)
                  + "\n󰍛 \(.used | mib)MiB / \(.total | mib)MiB"
                ) | join("\n\n")),
                class: (if $peak >= 90 then "critical"
                        elif $peak >= 70 then "warning"
                        else "" end),
              } end
          '
        '';
      };

      weather-script = pkgs.writeShellApplication {
        name = "waybar-weather";
        runtimeInputs = with pkgs; [
          curl
          jq
          coreutils
          util-linux
        ];
        text = ''
          unit="''${1:-f}"
          cache="/tmp/waybar-weather-cache.json"
          max_age=840  # 14 minutes (just under the 15min interval)
          fallback='{"text": "", "tooltip": ""}'

          # Fetch if cache is missing or stale, using flock to avoid duplicate fetches
          needs_fetch=false
          if [ ! -f "$cache" ]; then
            needs_fetch=true
          else
            age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
            [ "$age" -gt "$max_age" ] && needs_fetch=true
          fi

          if [ "$needs_fetch" = true ]; then
            (
              flock -w 15 9 || true
              # Re-check inside lock (another instance may have fetched)
              if [ ! -f "$cache" ] || [ "$(( $(date +%s) - $(stat -c %Y "$cache") ))" -gt "$max_age" ]; then
                location=$(curl -sf --max-time 5 "http://ip-api.com/json/?fields=lat,lon,city" || true)
                if [ -n "$location" ]; then
                  lat=$(echo "$location" | jq -r '.lat')
                  lon=$(echo "$location" | jq -r '.lon')
                  city=$(echo "$location" | jq -r '.city')
                  weather=$(curl -sf --max-time 10 \
                    "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m&temperature_unit=celsius&wind_speed_unit=kmh" || true)
                  if [ -n "$weather" ]; then
                    echo "$weather" | jq --arg city "$city" '. + {city: $city}' > "$cache.tmp"
                    mv "$cache.tmp" "$cache"
                  fi
                fi
              fi
            ) 9>/tmp/waybar-weather.lock
          fi

          # Read cache
          if [ ! -f "$cache" ]; then
            echo "$fallback"
            exit 0
          fi

          data=$(cat "$cache")
          code=$(echo "$data" | jq -r '.current.weather_code')
          humidity=$(echo "$data" | jq -r '.current.relative_humidity_2m')
          city=$(echo "$data" | jq -r '.city')

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

          if [ "$unit" = "c" ]; then
            temp_int=$(echo "$data" | jq -r '.current.temperature_2m | round')
            wind_int=$(echo "$data" | jq -r '.current.wind_speed_10m | round')
            text="$icon ''${temp_int}°C"
            tooltip="$desc"$'\n'"$city"$'\n'"󰖙 ''${temp_int}°C  󰖝 ''${wind_int} km/h  󰖎 ''${humidity}%"
          else
            temp_int=$(echo "$data" | jq -r '.current.temperature_2m | . * 9 / 5 + 32 | round')
            wind_int=$(echo "$data" | jq -r '.current.wind_speed_10m * 0.621371 | round')
            text="$icon ''${temp_int}°F"
            tooltip="$desc"$'\n'"$city"$'\n'"󰖙 ''${temp_int}°F  󰖝 ''${wind_int} mph  󰖎 ''${humidity}%"
          fi

          jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
        '';
      };

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

    in
    {
      key = "den:homeManager.waybar";
      programs.waybar = {
        enable = true;
        systemd.enable = true;
        # Sway's own anchor, deliberately NOT wayland.systemd.target (which
        # session/wayland.nix points at den-session.target, the union of the
        # user's sessions). The modules below are sway/workspaces, sway/mode,
        # sway/scratchpad and sway/window, so this bar means nothing outside
        # Sway: a user carrying a second desktop must not get it there.
        systemd.targets = [ "wayland-session@sway.target" ];
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
              max-length = 45;
            };

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
              exec = "${gpu-script}/bin/waybar-gpu";
              interval = 5;
            };

            "custom/weather-f" = {
              format = "{}";
              return-type = "json";
              exec = "${weather-script}/bin/waybar-weather f";
              interval = 900;
              on-click = "${weather-script}/bin/waybar-weather f";
            };

            "custom/weather-c" = {
              format = "{}";
              return-type = "json";
              exec = "${weather-script}/bin/waybar-weather c";
              interval = 900;
              on-click = "${weather-script}/bin/waybar-weather c";
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

          /* --- Sway mode --- */
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
      };
    };
}
