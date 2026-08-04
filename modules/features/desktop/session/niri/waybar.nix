{ self, ... }:
{
  # niri's slice of the bar: the modules that speak its IPC and nothing else.
  # The rest of it -- and the unit that starts this one -- is in
  # features/desktop/waybar.nix.
  flake.modules.homeManager.waybar-niri = {
    key = "den:homeManager.waybar-niri";
    imports = [ self.modules.homeManager.session-options ];

    # No counterparts to sway/mode or sway/scratchpad: niri has neither binding
    # modes nor a scratchpad, so the shared stylesheet's #mode and #scratchpad
    # rules simply match no widget here.
    den.session.bar.niri = {
      modules = [
        "niri/workspaces"
        "niri/window"
      ];

      settings = {
        "niri/window" = {
          max-length = 45;
        };
      };
    };
  };
}
