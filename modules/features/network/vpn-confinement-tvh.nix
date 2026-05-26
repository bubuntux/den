{ self, inputs, ... }:
{
  flake.nixosModules.vpn-confinement-tvh =
    { config, ... }:
    {
      imports = [
        self.nixosModules.sops
        inputs.vpn-confinement.nixosModules.default
      ];

      # secrets/appa.yaml must contain a `wireguard_config_tvh` key whose
      # value is a full wg-quick body (Interface + Peer) for the
      # streamlink-only VPN exit. Paste via `sops secrets/appa.yaml`.
      #
      # This is an independent circuit from the `wg` namespace defined in
      # [[vpn-confinement]] (used by the *arr / qbittorrent stack), so
      # streaming traffic doesn't share an exit IP with torrenting.
      sops.secrets.wireguard_config_tvh = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      # Every per-namespace kernel resource the upstream activation script
      # creates is keyed off (a) the namespace name and (b) the bridge IP:
      #
      #   netns                  ${name}              (wg-tvh)
      #   wireguard interface    ${name}0             (wg-tvh0)
      #   bridge interface       ${name}-br           (wg-tvh-br)
      #   veth pair              veth-${name}-br / veth-${name}
      #                          (14 chars — fits under the 15-char IFNAMSIZ
      #                          cap; longer names would silently truncate
      #                          and collide)
      #   iptables chain         ${name}-prerouting
      #   resolv.conf            /etc/netns/${name}/resolv.conf
      #   systemd unit           ${name}.service
      #   host /24 route         ${bridgeAddress}/24  via the bridge
      #
      # With wg pinned to its upstream defaults (192.168.15.x / fd93:9701:1d00::)
      # and wg-tvh on 192.168.16.x / fd93:9701:1d01::, ALL of the above
      # differ between the two namespaces. The host routing table ends up
      # with two non-overlapping /24s (one per bridge), so packets can be
      # disambiguated by destination address alone.
      #
      # Remaining external collision risks (NOT enforced here):
      #  - 192.168.{15,16}.x must not be used by anything on your physical
      #    LAN — would be shadowed by the bridge's /24 host route.
      #  - The VPN provider must not assign 192.168.16.x as the client's
      #    wg0 tunnel address. Real providers use 10.x or 100.64.x, so this
      #    is theoretical, but if it ever happens `wg-tvh.service` fails
      #    to activate and the fix is to renumber this block.
      vpnNamespaces.wg-tvh = {
        enable = true;
        wireguardConfigFile = config.sops.secrets.wireguard_config_tvh.path;
        namespaceAddress = "192.168.16.1";
        bridgeAddress = "192.168.16.5";
        namespaceAddressIPv6 = "fd93:9701:1d01::2";
        bridgeAddressIPv6 = "fd93:9701:1d01::1";
        # accessibleFrom lives in profile-nas alongside wg's — same reason
        # (avoid list duplication across multiple import paths).
      };
    };
}
