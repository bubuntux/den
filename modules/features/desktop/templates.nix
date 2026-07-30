{
  flake.modules.homeManager.templates =
    { config, lib, ... }:
    let
      dir = lib.removePrefix "${config.home.homeDirectory}/" config.xdg.userDirs.templates;
    in
    {
      key = "den:homeManager.templates";
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
