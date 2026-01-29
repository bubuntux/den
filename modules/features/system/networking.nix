{ lib, ... }:
{
  flake.nixosModules.networking = {
    networking = {
      # hostName = "${host}"; TODO
      nftables.enable = true;
      useDHCP = lib.mkDefault true;
    };
  };
}
