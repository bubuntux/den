_: {
  # Tools for inspecting what the kernel actually enumerated, needed whenever a
  # device is missing rather than misconfigured (docks, GPUs, USB peripherals).
  flake.modules.nixos.hardware-diagnostics =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # Bus enumeration
        pciutils # lspci
        usbutils # lsusb

        # Board and firmware identity from SMBIOS
        dmidecode

        # Storage health
        smartmontools # smartctl
        nvme-cli # nvme

        # Temperatures and fans
        lm_sensors # sensors

        # Link speed, duplex, and driver features
        ethtool

        # Thunderbolt/USB4 device listing. Just the CLI: boltctl needs boltd,
        # which only services.hardware.bolt.enable starts. On hosts without
        # that it still reports whether a TB domain exists at all.
        bolt # boltctl
      ];
    };
}
