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
              "privacy"
              "gamemode"
            ];

            modules-right = [
              "idle_inhibitor"
              "power-profiles-daemon"
              "pulseaudio"
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
                ""
                ""
              ];
              tooltip = true;
              tooltip-format = "{app}: {title}";
            };

            idle_inhibitor = {
              format = "{icon}";
              format-icons = {
                activated = "";
                deactivated = "";
              };
            };

            tray = {
              spacing = 5;
            };

            backlight = {
              format = "{percent}% {icon}";
              format-icons = [
                ""
                ""
                ""
                ""
                ""
                ""
                ""
                ""
                ""
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
                default = "";
                performance = "";
                balanced = "";
                power-saver = "";
              };
            };

            pulseaudio = {
              on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
            };

            clock = {
              format = "{:%I:%M %p}";
              format-alt = "{:%A, %B %d, %Y (%r)}";
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

            battery = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{capacity}% {icon}";
              format-icons = [
                ""
                ""
                ""
                ""
                ""
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
