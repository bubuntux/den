{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
    # TODO: What does auto-follow do?
    # inputs.flake-file.flakeModules.nix-auto-follow
  ];

  flake-file.description = "NixOS configuration flake using the dendritic pattern";

  flake-file.inputs.nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";
  flake-file.inputs.nixpkgs-unstable.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
}
