{ self, ... }:
{
  flake.nixosModules.profile-nas =
    { config, ... }:
    {
      imports = with self.nixosModules; [
        bazarr
        jellyfin
        radarr
        sonarr
        vpn-media
      ];

      # WireGuard private key for the VPN container (decrypted on host, bind-mounted in)
      sops.secrets.wireguard_private_key = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      # TODO: Replace placeholder values with your ProtonVPN WireGuard config.
      # Get these from ProtonVPN → Downloads → WireGuard configuration.
      den.vpn-media = {
        wgAddress = "10.2.0.2/32"; # TODO: ProtonVPN assigned address
        wgDns = [ "10.2.0.1" ]; # TODO: ProtonVPN DNS
        wgPrivateKeyFile = config.sops.secrets.wireguard_private_key.path;
        wgPeerPublicKey = "REPLACE_WITH_PROTONVPN_PUBLIC_KEY"; # TODO
        wgPeerEndpoint = "REPLACE_WITH_PROTONVPN_ENDPOINT:51820"; # TODO
      };
    };
}
