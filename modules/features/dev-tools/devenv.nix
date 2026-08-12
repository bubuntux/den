{ inputs, ... }:
{
  flake.modules.homeManager.devenv = {
    key = "den:homeManager.devenv";

    # programs.devenv landed after release-26.05 branched; the module itself needs
    # only lib.hm.shell.*, which 26.05 already has.
    imports = [ "${inputs.home-manager-unstable}/modules/programs/devenv.nix" ];

    programs.devenv.enable = true;
  };
}
