{ self, ... }:
{
  # Sway's slice of the bar: the modules that speak its IPC and nothing else.
  # The rest of it -- and the unit that starts this one -- is in
  # features/desktop/waybar.nix.
  flake.modules.homeManager.waybar-sway = {
    key = "den:homeManager.waybar-sway";
    imports = [ self.modules.homeManager.session-options ];

    den.session.bar.sway = {
      modules = [
        "sway/workspaces"
        "sway/mode"
        "sway/scratchpad"
        "sway/window"
      ];

      settings = {
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
      };
    };
  };
}
