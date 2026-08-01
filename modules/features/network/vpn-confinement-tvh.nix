{ self, inputs, ... }:
{
  flake.modules.nixos.vpn-confinement-tvh =
    { config, ... }:
    {
      key = "den:nixos.vpn-confinement-tvh";
      imports = [
        self.modules.nixos.sops
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

      # Every per-namespace resource is keyed off the namespace name and bridge
      # IP (netns, wg + bridge + veth interfaces, iptables chain, resolv.conf,
      # unit, /24 host route), so wg on 192.168.15.x and wg-tvh on .16.x share
      # nothing and the host can disambiguate by destination alone. The veth
      # names land at 14 chars, just under IFNAMSIZ -- longer ones truncate and
      # collide silently.
      #
      # Not enforced here: nothing on the physical LAN may use 192.168.{15,16}.x,
      # and the VPN provider must not hand out 192.168.16.x as the tunnel
      # address (theoretical; the fix is to renumber this block).
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
