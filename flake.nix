# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "NixOS configuration flake using the dendritic pattern";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      url = "github:nix-community/home-manager";
    };
    import-tree.url = "github:vic/import-tree";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "https://channels.nixos.org/nixos-25.11/nixexprs.tar.xz";
    nixpkgs-lib.follows = "nixpkgs";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

}
