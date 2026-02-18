{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
    # TODO: What does auto-follow do?
    # inputs.flake-file.flakeModules.nix-auto-follow
  ];

  flake-file.description = "NixOS configuration flake using the dendritic pattern";
}
