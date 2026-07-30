{ self, ... }:
{
  # Everything a real machine needs on top of bundle-base: a bootloader,
  # networking, unattended upgrades, secrets. A container takes bundle-base and
  # none of this (see features/virtualisation/work-container.nix), which is the
  # reason the two are separate bundles rather than one.
  flake.modules.nixos.bundle-host = {
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
      zsh
    ];
  };
}
