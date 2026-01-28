{ inputs, ... }:
{
  flake-file.inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem.treefmt = {
    programs.nixfmt.enable = true;
    programs.mdformat.enable = true;
  };

}
