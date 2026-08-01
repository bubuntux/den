{
  self,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
    concatLists
    isList
    filter
    hasPrefix
    attrNames
    elem
    ;
in
{
  # Output management for a bare Wayland session: kanshi drives the outputs a
  # compositor exposes over wlr-output-management, which is mutter's job under
  # GNOME. It names no compositor -- every session that would want it speaks that
  # protocol -- so it sits flat here next to the `monitors` schema it reads, and
  # session/wayland.nix is what pulls it in.
  #
  # Its unit follows wayland.systemd.target, which session/wayland.nix points at
  # den-session.target. Imported on its own it would fall back to Home Manager's
  # default of graphical-session.target and run under any desktop.
  flake.modules.homeManager.kanshi =
    { config, ... }:
    let
      # Generate output definition from monitor config
      monitorToOutput = m: {
        output = {
          criteria = m.name;
          status = if m.enabled then "enable" else "disable";
          mode = "${toString m.width}x${toString m.height}";
        }
        // (if m.transform != null then { transform = m.transform; } else { });
      };

      # Internal panels (eDP*). These are always connected now (the BIOS lid
      # switch is disabled, so closing the lid no longer removes the panel).
      # kanshi matches a profile only when the connected outputs exactly equal
      # the profile's outputs, so every profile must account for the panel:
      # profiles that don't use it reference it as disabled. That both lets
      # docked profiles match AND keeps the laptop screen off while docked.
      internalNames = map (m: m.name) (filter (m: hasPrefix "eDP" m.name) config.monitors);

      # Generate profile(s) from config. A profile value can be either a list
      # of names or an attrset of name = position.
      #
      # When a profile drives only external outputs (the internal panel is
      # unused), emit TWO variants so it matches whether or not the panel is
      # present -- kanshi activates a profile only when the connected output
      # SET equals the profile's, so a single profile cannot cover both states:
      #   - "<name>": panel connected -> disable it, keeping the laptop screen
      #     off while docked (the normal case once eDP-1 enumerates).
      #   - "<name>-no-panel": panel absent -> don't reference it at all. On a
      #     lid-closed boot i915 drops the eDP connector entirely ("unusable
      #     PPS, disabling eDP"), so a profile that names eDP-1 can never match
      #     then. This variant keeps the external layout (and its rotation)
      #     working in that clamshell state.
      profileToKanshi =
        name: value:
        let
          listed = if isList value then value else attrNames value;
          used =
            if isList value then
              # Simple list: just monitor names, no position override
              map (n: { criteria = n; }) value
            else
              # Attrset: name = position
              mapAttrsToList (n: pos: {
                criteria = n;
                position = pos;
              }) value;
          # Internal panels this profile doesn't explicitly use.
          unusedInternal = filter (n: !(elem n listed)) internalNames;
          disabledInternal = map (n: {
            criteria = n;
            status = "disable";
          }) unusedInternal;
        in
        if unusedInternal == [ ] then
          [
            {
              profile = {
                inherit name;
                outputs = used;
              };
            }
          ]
        else
          [
            {
              profile = {
                inherit name;
                outputs = used ++ disabledInternal;
              };
            }
            {
              profile = {
                name = "${name}-no-panel";
                outputs = used;
              };
            }
          ];

      # Generate all output definitions
      outputDefinitions = map monitorToOutput config.monitors;

      # Generate all profiles (each source profile may expand to several)
      profiles = concatLists (mapAttrsToList profileToKanshi config.monitorProfiles);
    in
    {
      key = "den:homeManager.kanshi";
      # Declares the `monitors` / `monitorProfiles` options read above --
      # imported here rather than left to whoever pulls this module in.
      imports = [ self.modules.homeManager.monitors ];
      services.kanshi = {
        # An output manager with nothing to manage does not sit idle. With no
        # monitors declared, Home Manager writes no config file, kanshi exits
        # 1 ("failed to parse config file"), and its Restart=always turns that
        # into a crash loop that ends in `failed`. Hosts push `monitors` at
        # every user (hosts/*/monitors.nix), so no machine hits this today --
        # a new host that installs a desktop before describing its displays
        # would, which the session VM test found by being exactly that host.
        enable = config.monitors != [ ];
        settings = outputDefinitions ++ profiles;
      };
    };
}
