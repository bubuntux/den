{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.appa = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      bundle-host
      (
        { modulesPath, ... }:
        {
          networking.hostName = "appa";
          system.stateVersion = "25.11";

          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          # TODO: Replace with actual hardware config (nixos-generate-config)
          boot.initrd.availableKernelModules = [ ];
          boot.initrd.kernelModules = [ ];
          boot.kernelModules = [ ];
          boot.extraModulePackages = [ ];

          fileSystems."/" = {
            device = "/dev/disk/by-uuid/TODO";
            fsType = "ext4";
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/TODO";
            fsType = "vfat";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          };

          swapDevices = [ ];
        }
      )
    ];
  };
}
