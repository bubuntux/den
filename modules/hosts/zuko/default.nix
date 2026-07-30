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
      # The only machine here that games, so this stays a capability the host
      # asks for rather than something profile-workstation implies.
      profile-gaming
      dell-precision-5680
      droidcam
      cachix-push
    ];

    networking.hostName = "zuko";
    system.stateVersion = "25.11";

    # Whole-machine desktop policy. Which environments are installed comes from
    # the profiles; which greeter presents them, and what it preselects, is the
    # host's call.
    den.desktop.loginManager = "greetd";
    services.displayManager.defaultSession = "sway";
  };
}
