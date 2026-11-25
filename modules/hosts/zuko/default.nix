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
      # Coalesce buffered writes over 15s (default 5s) to cut NVMe write churn.
      "vm.dirty_writeback_centisecs" = 1500;
      # BBR + fq (applies to both IPv4 and IPv6 despite the ipv4 prefix).
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };
    services.journald.extraConfig = "SystemMaxUse=1G";
  };
}
