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

    # The only hybrid-GPU machine here (Intel iGPU + NVIDIA dGPU), and the only
    # one where switcherooctl has anything to offload to. A 328 MiB python/gi
    # closure and a daemon, so it stays off the single-GPU hosts rather than
    # riding along with profile-gaming.
    services.switcherooControl.enable = true;

    # Profiles install the environments; the host picks the greeter. No
    # defaultSession: Sway is the only session here.
    den.desktop.loginManager = "greetd";
  };
}
