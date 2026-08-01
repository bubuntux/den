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
  # Output management for a bare Wayland session; mutter's job under GNOME.
  # Names no compositor, so it sits flat next to the `monitors` schema it reads.
  # Its unit follows wayland.systemd.target, which session/wayland.nix sets.
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

      # Every profile must account for the internal panel, because kanshi
      # matches on the exact output set. See CLAUDE.md, "Monitors and kanshi".
      internalNames = map (m: m.name) (filter (m: hasPrefix "eDP" m.name) config.monitors);

      # A profile value is a list of names or an attrset of name = position.
      # External-only profiles expand to two variants, with and without the
      # panel. See CLAUDE.md, "Monitors and kanshi".
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
      imports = [ self.modules.homeManager.monitors ];
      services.kanshi = {
        # With no monitors, Home Manager writes no config and kanshi crash-loops
        # on "failed to parse config file".
        enable = config.monitors != [ ];
        settings = outputDefinitions ++ profiles;
      };
    };
}
