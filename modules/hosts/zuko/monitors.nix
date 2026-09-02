{ self, ... }:
{
  # Display layout for this host. Deliberately per-host: katara and zuko sit at
  # the same desks today, but that is temporary and the two are expected to
  # diverge -- only the `monitors` option schema is shared (see
  # features/desktop/monitors.nix).
  flake.modules.nixos.zuko = {
    key = "den:nixos.zuko#monitors";
    home-manager.sharedModules = [
      {
        # The layout is pushed at every user on the host, so declare the schema
        # here too: only Sway users import the modules that read it.
        imports = [ self.modules.homeManager.monitors ];

        # Externals are matched by identity ("make model serial"), not the
        # DP-N connector name: the Thunderbolt dock enumerates them on a
        # different DP port each time (DP-5/7, DP-6/8, DP-6/9, ...), so any
        # port-name-based profile only matches some of the time. Identity is
        # stable, so a single docked profile now works regardless of port.
        monitors = [
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
          # Office external — single 1440p monitor, laptop stacked below it.
          # Claims workspaces 4-10 like the home landscape display; the two are
          # never connected at the same time, so no assignment conflict.
          {
            name = "Dell Inc. DELL U2724DE 2KT7QF4";
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
          # Office (dual) — landscape on top. Workspaces 4-7; shares those
          # numbers with the home/single-office externals above, which are
          # never connected at the same time as this pair.
          {
            name = "Dell Inc. DELL P2418D 29J0P8AO03XT";
            width = 2560;
            height = 1440;
            workspaces = [
              "4"
              "5"
              "6"
              "7"
            ];
          }
          # Office (dual) — portrait on the right. Workspaces 8-10.
          {
            name = "Dell Inc. DELL P2418D 29J0P8AO1E9T";
            width = 2560;
            height = 1440;
            transform = "90";
            workspaces = [
              "8"
              "9"
              "10"
            ];
          }
          # Office (sea2u-33-6-3) — portrait on the left. Workspaces 1-3.
          {
            name = "Dell Inc. DELL U2722DE BBYP1H3";
            width = 2560;
            height = 1440;
            transform = "270";
            workspaces = [
              "1"
              "2"
              "3"
            ];
          }
          # Office (sea2u-33-6-3) — landscape in the middle, laptop below it.
          {
            name = "Dell Inc. DELL U2722DE 6ZTJ193";
            width = 2560;
            height = 1440;
            workspaces = [
              "4"
              "5"
              "6"
              "7"
            ];
          }
          # Built-in laptop display, listed last: sway accumulates the repeated
          # `workspace N output ...` lines and takes the first *available*
          # output, so the panel has to be every workspace's last resort rather
          # than any workspace's first choice. It takes 1-3 where it sits beside
          # a single external, and 8-10 where it sits underneath one.
          {
            name = "eDP-1";
            width = 3840;
            height = 2400;
            workspaces = [
              "1"
              "2"
              "3"
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
          # Office: external on top, laptop centered underneath it (the 1920px
          # panel centered under the 2560px external -> x = (2560-1920)/2 = 320).
          office = {
            "Dell Inc. DELL U2724DE 2KT7QF4" = "0,0";
            "eDP-1" = "320,1440";
          };
          # Office (dual): landscape external on top, laptop right-aligned
          # beneath it (right edge at x=2560 -> x = 2560-1920 = 640), and a
          # tall portrait external on the right spanning both (1440 wide after
          # the 270 rotation, so it sits at x=2560, right of the landscape).
          office-dual = {
            "Dell Inc. DELL P2418D 29J0P8AO03XT" = "0,0";
            "eDP-1" = "640,1440";
            "Dell Inc. DELL P2418D 29J0P8AO1E9T" = "2560,0";
          };
          # Office (sea2u-33-6-3): portrait on the left, landscape in the middle
          # with the laptop directly beneath it. The portrait is dropped 80px so
          # its bottom edge meets the laptop's (80 + 2560 = 1440 + 1200).
          office-sea2u-33-6-3 = {
            "Dell Inc. DELL U2722DE BBYP1H3" = "0,80";
            "Dell Inc. DELL U2722DE 6ZTJ193" = "1440,0";
            "eDP-1" = "1440,1440";
          };
        };
      }
    ];
  };
}
