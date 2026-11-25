{ self, ... }:
{
  # Everything a real machine needs on top of bundle-base: a bootloader,
  # networking, unattended upgrades, secrets. A container takes bundle-base and
  # none of this (see features/virtualisation/work-container.nix), which is the
  # reason the two are separate bundles rather than one.
  flake.modules.nixos.bundle-host =
    { lib, ... }:
    {
      key = "den:nixos.bundle-host";
      imports = with self.modules.nixos; [
        bundle-base
        auto-upgrade
        boot
        diagnostics
        networking
        sops
        sudo-rs
        ntpd-rs
        dirty-frag-mitigation
        lan-only
        zsh
      ];

      boot.kernelModules = [ "tcp_bbr" ];

      boot.kernel.sysctl = {
        # Coalesce buffered writes over 15s (default 5s) to cut SSD/HDD write churn.
        "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
        # BBR + fq (applies to both IPv4 and IPv6 despite the ipv4 sysctl prefix).
        "net.core.default_qdisc" = lib.mkDefault "fq";
        "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
      };

      services.journald.extraConfig = lib.mkDefault "SystemMaxUse=1G";
    };
}
