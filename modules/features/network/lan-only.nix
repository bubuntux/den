{ self, ... }:
{
  flake.modules.nixos.lan-only =
    { config, lib, ... }:
    let
      lanIpv4 = lib.concatStringsSep ", " self.lib.lan.ipv4;
      lanIpv6 = lib.concatStringsSep ", " self.lib.lan.ipv6;

      # A drop in any base chain is final, so this filters ahead of every
      # port the regular firewall opens without having to know them.
      lanOnlyRules = ''
        iifname "lo" accept
        ct state { established, related } accept
        ip saddr { ${lanIpv4} } accept
        ip6 saddr { ${lanIpv6} } accept
        meta l4proto { tcp, udp } counter drop
      '';
    in
    {
      key = "den:nixos.lan-only";

      options.den.lanOnly = lib.mkEnableOption ''
        dropping every new inbound TCP/UDP connection that does not come from
        the LAN, including ports opened by services, port forwards and DNAT'd
        container ports. Outbound connections, and the replies to them, are
        unaffected
      '';

      config = lib.mkIf config.den.lanOnly {
        networking.nftables.tables.lan-only = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority filter - 10; policy accept;
              ${lanOnlyRules}
            }

            chain forward {
              type filter hook forward priority filter - 10; policy accept;
              ${lanOnlyRules}
            }
          '';
        };
      };
    };
}
