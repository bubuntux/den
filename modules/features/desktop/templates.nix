{
  flake.homeModules.templates =
    { config, lib, ... }:
    let
      dir = lib.removePrefix "${config.home.homeDirectory}/" config.xdg.userDirs.templates;
    in
    {
      home.file = {
        "${dir}/script.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail
          '';
        };

        "${dir}/note.md".text = ''
          # Title

          -
        '';
      };
    };
}
