{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        NIX_CONFIG = "extra-experimental-features = nix-command flakes ca-derivations pipe-operators";
        packages = with pkgs; [
          git
          home-manager
          nix

          sops
          age
          ssh-to-age
        ];
        shellHook = ''
          if age_key=$(ssh-to-age -private-key -i ~/.ssh/id_ed25519); then
            export SOPS_AGE_KEY=$age_key
          else
            echo "shell.nix: no age key from ~/.ssh/id_ed25519, sops cannot decrypt" >&2
          fi
          unset age_key
        '';
      };
    };
}
