{
  description = "bbtOS";

  inputs = {
    # Nix ecosystem
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    hardware.url = "github:nixos/nixos-hardware";

    # Nix Community
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "unstable";
    };
    #impermanence.url = "github:nix-community/impermanence";

    # Snowfall
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Treefmt
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #sops-nix = {
    #  url = "github:mic92/sops-nix";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs =
    inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;
      snowfall.namespace = "bbtos";
      channels-config.allowUnfree = true;
      outputs-builder =
        channels:
        let
          treefmtConfig = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.mdformat.enable = true;
          };
          treefmtEval = inputs.treefmt-nix.lib.evalModule (channels.nixpkgs) treefmtConfig;
        in
        {
          formatter = treefmtEval.config.build.wrapper;
        };
    };
}
