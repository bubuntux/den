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
      profile-gaming
      dell-precision-5680
      droidcam
      cachix-push
    ];

    networking.hostName = "zuko";
    system.stateVersion = "25.11";

    # The only hybrid-GPU machine here (Intel iGPU + NVIDIA dGPU), so it is the
    # only one that installs a render-offload command. `hardware.nvidia.prime`
    # in dell-precision-5680.nix already generates the script; this just gives
    # it the vendor-free name every host would use, so a Steam launch option
    # reads `gpu-offload %command%` whatever the machine.
    hardware.nvidia.prime.offload.offloadCmdMainProgram = "gpu-offload";

    # Profiles install the environments; the host picks the greeter. No
    # defaultSession: Sway is the only session here.
    den.desktop.loginManager = "greetd";
  };
}
