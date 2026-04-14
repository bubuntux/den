{ inputs, ... }:
{
  flake-file.inputs.gws.url = "github:googleworkspace/cli";
  flake-file.inputs.gws.inputs.nixpkgs.follows = "nixpkgs";

  flake.homeModules.gws =
    { pkgs, lib, ... }:
    {
      home.packages = [
        inputs.gws.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.google-cloud-sdk
      ];
      programs.claude-code.skills =
        let
          skillsDir = inputs.gws + "/skills";
          dirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir);
        in
        builtins.mapAttrs (name: _: skillsDir + "/${name}") dirs;
    };
}
