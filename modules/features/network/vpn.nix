{
  flake.modules.nixos.vpn =
    { pkgs, ... }:
    {
      key = "den:nixos.vpn";
      networking.firewall.checkReversePath = "loose";
      environment.systemPackages = with pkgs; [
        wireguard-tools
        proton-vpn
        proton-vpn-cli
      ];
    };
}
