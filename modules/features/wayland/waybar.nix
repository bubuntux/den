{
  self,
  ...
}:
{
  # Home Manager module for waybar configuration
  flake.homeModules.waybar =
    { pkgs, ... }:
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
            ];

            modules-center = [
              "systemd-failed-units"
              "mpris"
              "privacy"
              "gamemode"
            ];

            modules-right = [
              "custom/weather"
              "idle_inhibitor"
              "power-profiles-daemon"
              "group/hardware"
              "backlight"

              "wireplumber"
              "clock"
              "battery"
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
                  months = "<span color='#ffead3'><b>{}</b></span>";
                  days = "<span color='#ecc6d9'><b>{}</b></span>";
                  weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                  weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                  today = "<span color='#ff6699'><b><u>{}</u></b></span>";
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

            "group/hardware" = {
              orientation = "inherit";
              drawer = {
                transition-duration = 300;
                transition-left-to-right = false;
              };
              modules = [
                "cpu"
                "memory"
                "temperature"
              ];
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
              format = "󰔏 {temperatureC}°C";
              tooltip = true;
              critical-threshold = 80;
              warning-threshold = 60;
            };

            "custom/weather" = {
              format = "{}";
              return-type = "json";
              exec = "${pkgs.wttrbar}/bin/wttrbar --location auto --fahrenheit --main-indicator temp_F";
              interval = 900;
              on-click = "${pkgs.wttrbar}/bin/wttrbar --location auto --fahrenheit --main-indicator temp_F";
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
      };
    };

  # NixOS module that includes waybar home module
  flake.nixosModules.waybar =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.waybar ];
    };
}
