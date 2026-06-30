# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "NixOS configuration flake using the dendritic pattern";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    aws-agent-toolkit = {
      url = "github:aws/agent-toolkit-for-aws";
      flake = false;
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    glab-cli = {
      url = "gitlab:gitlab-org/cli";
      flake = false;
    };
    gws = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix.url = "github:helix-editor/helix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    nixpkgs-xdpw-pin.url = "github:NixOS/nixpkgs/3e41b24abd260e8f71dbe2f5737d24122f972158";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
  };
}
