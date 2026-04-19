{
  flake.nixosModules.vpn =
    { pkgs, ... }:
    {
      networking.firewall.checkReversePath = "loose";
      environment.systemPackages = with pkgs; [
        wireguard-tools
        proton-vpn
        proton-vpn-cli
      ];
    };
}
