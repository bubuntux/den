{ inputs, ... }:
{
  flake.modules.homeManager.devenv =
    { pkgs, ... }:
    {
      key = "den:homeManager.devenv";

      # programs.devenv landed after release-26.05 branched; the module itself needs
      # only lib.hm.shell.*, which 26.05 already has.
      imports = [ "${inputs.home-manager-unstable}/modules/programs/devenv.nix" ];

      programs.devenv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;

        # devenv cuts releases far faster than the stable channel picks them up.
        package =
          (import inputs.nixpkgs-unstable {
            inherit (pkgs.stdenv.hostPlatform) system;
          }).devenv;
      };
    };
}
