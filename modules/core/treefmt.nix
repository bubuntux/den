{ inputs, ... }:
{
  flake-file.inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  flake-file.inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem.treefmt = {
    programs.biome.enable = true;
    programs.mdformat.enable = true;
    programs.nixfmt.enable = true;
    programs.shfmt.enable = true;
    programs.taplo.enable = true;
  };

}
