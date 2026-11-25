{ inputs, ... }:
{
  flake-file.inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  flake-file.inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem.treefmt = {
    # sops writes encrypted blobs; waybar uses GTK3 CSS (@define-color / @var)
    # which biome's standard CSS parser rejects.
    settings.excludes = [
      "secrets/*"
      "modules/features/desktop/_waybar-style.css"
    ];

    programs.biome.enable = true;
    programs.mdformat.enable = true;
    programs.nixfmt.enable = true;
    programs.shfmt = {
      enable = true;
      indent_size = 2;
      simplify = true;
    };
    programs.taplo.enable = true;
  };

}
