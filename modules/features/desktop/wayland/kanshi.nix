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
  # Home Manager module for kanshi display management
  flake.homeModules.kanshi =
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
      # Note: monitors module must be imported by the parent NixOS module
      services.kanshi = {
        enable = true;
        settings = outputDefinitions ++ profiles;
      };
    };

  # NixOS module that includes kanshi home module
  flake.nixosModules.kanshi =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.kanshi ];
    };
}
