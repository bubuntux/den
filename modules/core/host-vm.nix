{ self, ... }:
{
  perSystem =
    {
      system,
      lib,
      pkgs,
      ...
    }:
    let
      # Filter configurations that match the current system
      compatibleHosts = lib.filterAttrs (
        _: config: config.config.nixpkgs.system == system
      ) self.nixosConfigurations;

      # Generate apps for each compatible host
      vmApps = lib.mapAttrs' (
        name: config:
        lib.nameValuePair "${name}-vm" {
          type = "app";
          program =
            let
              vmScript = "${config.config.system.build.vm}/bin/run-${name}-vm";
              wrapper = pkgs.writeShellScriptBin "run-${name}-vm-wrapper" ''
                export QEMU_OPTS="-m 4096 -smp 2 -enable-kvm -cpu host -vga virtio -display gtk,gl=on $QEMU_OPTS"
                exec ${vmScript} "$@"
              '';
            in
            "${lib.getExe wrapper}";
          meta.description = "Run ${name} as a NixOS Virtual Machine";
        }
      ) compatibleHosts;
    in
    {
      apps = vmApps;
    };
}
