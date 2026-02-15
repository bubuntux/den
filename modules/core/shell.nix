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

          age
          gnupg
          sops
          ssh-to-age
        ];
      };
    };
}
