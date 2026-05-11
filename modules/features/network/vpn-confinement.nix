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

      # secrets/appa.yaml must contain a `wireguard_config` key whose value is
      # the full body of a wg0.conf (Interface + Peer). Grab it from
      # ProtonVPN → Downloads → WireGuard configuration and paste it via
      # `sops secrets/appa.yaml`. In a VM build the secret exists in the yaml
      # so sops-install-secrets passes, but the VM's host SSH key isn't on
      # the sops keyring, so wg.service fails to decrypt and qbittorrent /
      # prowlarr (which depend on the namespace) don't start. The rest of
      # the system boots normally.
      sops.secrets.wireguard_config = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      vpnNamespaces.wg = {
        enable = true;
        wireguardConfigFile = config.sops.secrets.wireguard_config.path;
        # accessibleFrom lives in the importing profile (profile-nas) so the
        # list isn't duplicated when this module is evaluated through multiple
        # service paths. portMappings and openVPNPorts live with each service
        # — they don't duplicate because each service contributes its own.
      };
    };
}
