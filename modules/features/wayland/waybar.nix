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
          #custom-weather {
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
