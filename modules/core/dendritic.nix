{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
    # TODO: What does auto-follow do?
    # inputs.flake-file.flakeModules.nix-auto-follow
  ];

  flake-file.description = "NixOS configuration flake using the dendritic pattern";

  flake-file.inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

  perSystem = _: {
    apps.write-flake.meta.description = "Regenerate flake.nix from flake-file configuration";
    apps.write-inputs.meta.description = "Write flake inputs from flake-file configuration";
    apps.write-lock.meta.description = "Write the lock file for the current flake backend";
  };
}
