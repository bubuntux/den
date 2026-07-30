{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.katara = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = [ self.modules.nixos.katara ];
  };

  # Host identity and the roles it plays. Hardware and display layout are
  # separate fragments of this same module name (hardware.nix, monitors.nix) --
  # flake.modules merges them into one imports list, so each fragment gets its
  # own `key`.
  flake.modules.nixos.katara = {
    key = "den:nixos.katara#host";
    imports = with self.modules.nixos; [
      profile-workstation
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
    ];

    networking.hostName = "katara";
    system.stateVersion = "25.11";
  };
}
