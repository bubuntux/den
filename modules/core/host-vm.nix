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

                # If the invoking user has an SSH dir, expose it to the VM
                # under the 9p tag `user-ssh`. The sops module mounts it at
                # /run/host-ssh inside the VM so secrets encrypted to the
                # user's age key can decrypt. Skipped silently when absent.
                if [ -d "$HOME/.ssh" ]; then
                  export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=$HOME/.ssh,security_model=mapped-xattr,mount_tag=user-ssh,readonly=on"
                fi

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
