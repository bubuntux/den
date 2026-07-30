{ self, ... }:
{
  # Display layout for this host. Deliberately per-host: katara only ever sits
  # at the home desk, so it carries no office profiles -- zuko keeps those.
  # Only the `monitors` option schema is shared (see
  # features/desktop/monitors.nix).
  flake.modules.nixos.katara = {
    key = "den:nixos.katara#monitors";
    home-manager.sharedModules = [
      {
        # The layout is pushed at every user on the host, so declare the schema
        # here too: only Sway users import the modules that read it, and this
        # would otherwise be an undeclared option for a GNOME-only user.
        imports = [ self.modules.homeManager.monitors ];

        # Externals are matched by identity ("make model serial"), not the
        # DP-N connector name: the Thunderbolt dock enumerates them on a
        # different DP port each time (DP-5/7, DP-6/8, DP-6/9, ...), so any
        # port-name-based profile only matches some of the time. Identity is
        # stable, so a single docked profile now works regardless of port.
        monitors = [
          # Built-in laptop display. Auxiliary monitor: workspaces 1-3 live
          # here whenever it's on (undocked, where 4-10 fall back to it since
          # their externals are absent). kanshi disables it entirely when
          # docked; see the internal-panel handling in kanshi.nix.
          {
            name = "eDP-1";
            width = 1920;
            height = 1200;
            workspaces = [
              "1"
              "2"
              "3"
            ];
          }
          # Left external — portrait
          {
            name = "Dell Inc. DELL U2722DE J85KV83";
            width = 2560;
            height = 1440;
            transform = "270";
            workspaces = [
              "1"
              "2"
              "3"
            ];
          }
          # Right external — landscape
          {
            name = "Dell Inc. DELL U2722DE 1B5KV83";
            width = 2560;
            height = 1440;
            workspaces = [
              "4"
              "5"
              "6"
              "7"
              "8"
              "9"
              "10"
            ];
          }
        ];

        monitorProfiles = {
          laptop = [ "eDP-1" ];
          docked = {
            "Dell Inc. DELL U2722DE J85KV83" = "0,0";
            "Dell Inc. DELL U2722DE 1B5KV83" = "1440,669";
          };
        };
      }
    ];
  };
}
