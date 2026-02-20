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
          export SOPS_AGE_KEY=$(ssh-to-age -private-key -i ~/.ssh/id_ed25519 2>/dev/null)
        '';
      };
    };
}
