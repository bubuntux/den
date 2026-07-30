{ ... }:
{
  flake.modules.nixos.appa = {
    key = "den:nixos.appa#network";

    # Static ULA on eno1, in addition to SLAAC-derived ULA and public
    # global addresses. Gives services a stable, short internal address
    # to bind to. The router already announces fdf9:ef45:81dc:2200::/64,
    # so this is reachable from any LAN host without extra routes.
    networking.interfaces.eno1.ipv6.addresses = [
      {
        address = "fdf9:ef45:81dc:2200::a";
        prefixLength = 64;
      }
    ];

    # Without this, NixOS's dhcpcd module auto-emits `noipv6rs` for
    # any interface with a manually declared IPv6 address, which kills
    # SLAAC on eno1 — the public 2605:… and router-announced ULA stop
    # renewing and disappear after the lease expires. Forcing IPv6rs=true
    # keeps dhcpcd soliciting RAs so the static ULA and SLAAC coexist.
    networking.dhcpcd.IPv6rs = true;
  };
}
