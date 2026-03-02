{
  self,
  lib,
  ...
}:
let
  inherit (lib) mapAttrsToList isList;
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

      # Generate profile from config
      # Profile can be either a list of names or an attrset of name = position
      profileToKanshi =
        name: value:
        let
          outputs =
            if isList value then
              # Simple list: just monitor names, no position override
              map (n: { criteria = n; }) value
            else
              # Attrset: name = position
              mapAttrsToList (n: pos: {
                criteria = n;
                position = pos;
              }) value;
        in
        {
          profile = {
            inherit name outputs;
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
