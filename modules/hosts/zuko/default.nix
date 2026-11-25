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
      dell-precision-5690
      droidcam
      cachix-push
      immich-ml
    ];

    networking.hostName = "zuko";
    system.stateVersion = "25.11";

    den.desktop.loginManager = "greetd";
    services.displayManager.defaultSession = "sway";

    programs.nh.flake = "/etc/nixos";

    boot.kernel.sysctl = {
      # 62 GiB RAM workstation: avoid premature swap and retain dentry/inode cache longer.
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };
  };
}
