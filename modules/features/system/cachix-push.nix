{ self, ... }:
{
  flake.nixosModules.cachix-push =
    { config, pkgs, ... }:
    {
      imports = [ self.nixosModules.sops ];

      sops.secrets.cachix_auth_token = {
        sopsFile = "${self}/secrets/zuko.yaml";
        restartUnits = [ "nix-daemon.service" ];
      };

      nix.settings.post-build-hook = pkgs.writeShellScript "cachix-push-den" ''
        set -eu
        set -f
        export IFS=' '
        TOKEN_FILE=${config.sops.secrets.cachix_auth_token.path}
        if [ ! -r "$TOKEN_FILE" ]; then
          echo "cachix-push: token not readable, skipping" >&2
          exit 0
        fi
        export CACHIX_AUTH_TOKEN="$(cat "$TOKEN_FILE")"
        ${pkgs.cachix}/bin/cachix push den $OUT_PATHS \
          || echo "cachix-push: upload failed" >&2
      '';
    };
}
