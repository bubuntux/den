{
  self,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
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

      # Generate profile from config
      # Profile can be either a list of names or an attrset of name = position
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
          # Disable any internal panel this profile doesn't explicitly use.
          disabledInternal = map (n: {
            criteria = n;
            status = "disable";
          }) (filter (n: !(elem n listed)) internalNames);
        in
        {
          profile = {
            inherit name;
            outputs = used ++ disabledInternal;
          };
        };

      # Generate all output definitions
      outputDefinitions = map monitorToOutput config.monitors;

      # Generate all profiles
      profiles = mapAttrsToList profileToKanshi config.monitorProfiles;
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
