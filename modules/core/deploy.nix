{ inputs, self, ... }:
{
  flake-file.inputs.deploy-rs.url = "github:serokell/deploy-rs";
  flake-file.inputs.deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

  # deployChecks is deliberately absent: both of its checks carry profile.path
  # with string context, so they build every node's closure. See CLAUDE.md.
  perSystem =
    {
      system,
      lib,
      pkgs,
      ...
    }:
    let
      # deploy-rs packages only four systems, and a closure has to be built by
      # the machine that pushes it.
      deployableNodes = lib.filterAttrs (
        name: _:
        self.nixosConfigurations ? ${name}
        && self.nixosConfigurations.${name}.config.nixpkgs.system == system
      ) self.deploy.nodes;

      deployApps = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "deploy-${name}" {
          type = "app";
          program =
            let
              wrapper = pkgs.writeShellScriptBin "deploy-${name}" ''
                exec ${lib.getExe inputs.deploy-rs.packages.${system}.default} "${self}#${name}" "$@"
              '';
            in
            "${lib.getExe wrapper}";
          meta.description = "Deploy ${name} with deploy-rs";
        }
      ) deployableNodes;
    in
    {
      apps = deployApps;
    };
}
