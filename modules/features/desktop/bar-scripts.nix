{ self, ... }:
{
  # The two readings no bar has a native module for. Shared, so waybar and
  # ironbar cannot drift into showing different numbers -- a function of pkgs
  # rather than a module, since both renderers only want the derivations.
  flake.lib.barScripts =
    pkgs:
    let
      # Catppuccin Mocha, mirroring the colour definitions in whichever bar
      # renders this. Pango markup cannot reference CSS colour names, so the
      # widget needs the literals. Colour here means vendor and nothing else --
      # load is an underline. AMD is peach rather than the red its brand
      # suggests: @red is what every alert in these bars uses.
      gpuVendorColors = {
        nvidia = "#a6e3a1"; # @green
        intel = "#89b4fa"; # @blue
        amd = "#fab387"; # @peach
        unknown = "#cdd6f4"; # @text
      };
    in
    {
      # One widget for however many GPUs the host has, of whatever make: nvtop
      # emits one JSON shape for every backend, so katara's APU, zuko's hybrid
      # pair and a discrete card all share this code path.
      gpu = pkgs.writeShellApplication {
        name = "bar-gpu";
        runtimeInputs = [
          pkgs.jq
          (self.lib.nvtop pkgs)
        ];
        text = ''
          nvtop_gpus='[]'
          if snapshot=$(nvtop -s 2>/dev/null) && [ -n "$snapshot" ]; then
            # .processes is every GPU client with its full cmdline. Not for a bar.
            nvtop_gpus=$(jq -c 'map(del(.processes))' <<<"$snapshot") || nvtop_gpus='[]'
          fi

          jq -nc --argjson nvtop "$nvtop_gpus" \
                 --argjson colors '${builtins.toJSON gpuVendorColors}' '
            # nvtop reports every value unit-suffixed ("47C", "5W"), and "N/A"
            # wherever a backend has no such sensor -- Intel reports no power.
            def num: (tostring | capture("(?<n>[0-9]+(\\.[0-9]+)?)") | .n | tonumber) // 0;
            def mib: (. / 1048576 | floor);

            # The reported name is all there is to go on: nvtop says "AMD Radeon
            # 780M Graphics", "Intel Alderlake_p", or whatever NVML hands over,
            # which leads with "NVIDIA". Checked most- to least-specific.
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
            | map(. + { color: ($colors[.name | vendor] // $colors.unknown) }) as $gpus
            | ($gpus | map(select(.util > 0))) as $busy
            | ($busy | map(.util) | max // 0) as $peak
            | if $busy == [] then { text: "", tooltip: "" } else {
                # Markup, so device names have to be escaped -- waybar renders
                # both the label and the tooltip through Pango.
                # The icon goes inside the span, so each GPU is one unit in one
                # colour. A single shared icon would have to take one vendor
                # colour and would then contradict the reading beside it.
                # (No apostrophes in here: the jq program is shell single-quoted.)
                text: ($busy
                  | map("<span color=\"\(.color)\">󰢮 \(.util)%</span>")
                  | join(" ")),
                # Every GPU, not just the busy ones: an idle card still has a
                # temperature worth reading.
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

      weather = pkgs.writeShellApplication {
        name = "bar-weather";
        runtimeInputs = with pkgs; [
          curl
          jq
          coreutils
          util-linux
        ];
        text = ''
          unit="''${1:-f}"
          cache="/tmp/bar-weather-cache.json"
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
            ) 9>/tmp/bar-weather.lock
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
    };
}
