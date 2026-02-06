{ self, ... }:
{
  perSystem =
    {
      system,
      lib,
      ...
    }:
    let
      # Filter configurations that match the current system
      compatibleHosts = lib.filterAttrs (
        _: config: config.config.nixpkgs.hostPlatform.system == system
      ) self.nixosConfigurations;

      # Generate apps for each compatible host
      vmApps = lib.mapAttrs' (
        name: config:
        lib.nameValuePair "${name}-vm" {
          type = "app";
          program = "${config.config.system.build.vm}/bin/run-${name}-vm";
        }
      ) compatibleHosts;
    in
    {
      apps = vmApps;
    };
}
