{ self, inputs, ... }:
{
  flake-file.inputs.vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

  flake.nixosModules.vpn-confinement =
    { config, ... }:
    {
      imports = [
        self.nixosModules.sops
        inputs.vpn-confinement.nixosModules.default
      ];

      # Before this works, secrets/appa.yaml must contain a `wireguard_config`
      # key whose value is the full body of a wg0.conf (Interface + Peer).
      # Grab it from ProtonVPN → Downloads → WireGuard configuration and paste
      # it under that key with `sops secrets/appa.yaml`. The .sops.yaml file
      # also needs a creation rule for secrets/appa\.yaml and appa's age key.
      sops.secrets.wireguard_config = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      vpnNamespaces.wg = {
        enable = true;
        wireguardConfigFile = config.sops.secrets.wireguard_config.path;

        # LAN ranges that can reach the namespaced services through the host.
        # Adjust to match the real /mnt/data LAN segment.
        accessibleFrom = [
          "127.0.0.1"
          "192.168.0.0/16"
          "10.0.0.0/8"
        ];
        # Per-service portMappings and openVPNPorts live with the service
        # modules (qbittorrent.nix, prowlarr.nix). They merge into this
        # namespace automatically.
      };
    };
}
