{ lib, ... }:
{
  # Single source of truth for LAN allowlists. Exposed at the flake level
  # (not as a NixOS option) so it can be referenced by modules without
  # tripping the module-system's "option declared twice" error when this
  # module is reached via multiple import paths (e.g. profile-laptop and
  # bundle-desktop both pulling in bundle-host).
  #
  # Excludes loopback — add `127.0.0.0/8` / `::1` at the call site when
  # loopback should also match.
  flake.lib.lan = {
    ipv4 = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
    ipv6 = [
      "fe80::/10"
      "fd00::/8"
    ];
  };

  flake.nixosModules.networking = _: {
    networking = {
      # hostName = "${host}"; TODO
      nftables.enable = true;
      useDHCP = lib.mkDefault true;
    };
  };
}
