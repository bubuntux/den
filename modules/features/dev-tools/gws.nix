{ inputs, ... }:
{
  flake-file.inputs.gws.url = "github:googleworkspace/cli";
  flake-file.inputs.gws.inputs.nixpkgs.follows = "nixpkgs";

  flake.homeModules.gws =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.gws.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.google-cloud-sdk
      ];
      programs.claude-code.skillsDir = "${inputs.gws}/skills";
      programs.claude-code.settings.permissions.allow = [ "Bash(gws *)" ];
    };
}
