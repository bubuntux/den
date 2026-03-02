{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  # Home Manager module for monitor configuration
  flake.homeModules.monitors = _: {
    options.monitors = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              example = "DP-1";
              description = "Output name (e.g., DP-1, eDP-1, HDMI-A-1)";
            };
            primary = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this is the primary monitor";
            };
            width = mkOption {
              type = types.int;
              example = 1920;
              description = "Horizontal resolution";
            };
            height = mkOption {
              type = types.int;
              example = 1080;
              description = "Vertical resolution";
            };
            refreshRate = mkOption {
              type = types.int;
              default = 60;
              description = "Refresh rate in Hz";
            };
            scale = mkOption {
              type = types.float;
              default = 1.0;
              description = "Scale factor";
            };
            transform = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "270";
              description = "Transform/rotation (90, 180, 270, flipped, etc.)";
            };
            enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Whether the monitor is enabled";
            };
            workspaces = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [
                "1"
                "2"
                "3"
              ];
              description = "Workspaces to assign to this monitor";
            };
          };
        }
      );
      default = [ ];
      description = "Monitor configurations";
    };

    options.monitorProfiles = mkOption {
      type = types.attrsOf (types.either (types.listOf types.str) (types.attrsOf types.str));
      default = { };
      example = {
        laptop = [ "eDP-1" ];
        docked = {
          "eDP-1" = "1440,1440";
          "DP-1" = "0,0";
          "DP-2" = "2560,0";
        };
      };
      description = ''
        Monitor profiles for different setups.
        Can be a list of monitor names (auto positions) or an attrset of name = "position".
      '';
    };
  };
}
