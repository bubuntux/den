{ lib, ... }:
{
  flake.nixosModules.networking = _: {
    networking = {
      # hostName = "${host}"; TODO
      nftables.enable = true;
      useDHCP = lib.mkDefault true;
    };
  };
}
