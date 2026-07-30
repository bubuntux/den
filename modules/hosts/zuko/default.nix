{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.zuko = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = [ self.modules.nixos.zuko ];
  };

  # Host identity and the roles it plays. Hardware and display layout are
  # separate fragments of this same module name (hardware.nix, monitors.nix) --
  # flake.modules merges them into one imports list, so each fragment gets its
  # own `key`.
  flake.modules.nixos.zuko = {
    key = "den:nixos.zuko#host";
    imports = with self.modules.nixos; [
      profile-workstation
      dell-precision-5680
      droidcam
      cachix-push
    ];

    networking.hostName = "zuko";
    system.stateVersion = "25.11";
  };
}
