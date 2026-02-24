{ self, ... }:
{
  flake.nixosModules.profile-nas = _: {
    imports = with self.nixosModules; [
      bazarr
      jellyfin
      radarr
      sonarr
      vpn-media
    ];

    # TODO: Uncomment and set sopsFile when NAS host secrets are configured
    # sops.secrets.wireguard_private_key = {
    #   sopsFile = "${self}/secrets/<hostname>.yaml";
    # };

    # TODO: Replace placeholder values with your ProtonVPN WireGuard config.
    # Get these from ProtonVPN → Downloads → WireGuard configuration.
    den.vpn-media = {
      wgAddress = "10.2.0.2/32"; # TODO: ProtonVPN assigned address
      wgDns = [ "10.2.0.1" ]; # TODO: ProtonVPN DNS
      wgPrivateKeyFile = "/run/secrets/wireguard_private_key"; # TODO: use config.sops.secrets path once secrets are configured
      wgPeerPublicKey = "REPLACE_WITH_PROTONVPN_PUBLIC_KEY"; # TODO
      wgPeerEndpoint = "REPLACE_WITH_PROTONVPN_ENDPOINT:51820"; # TODO
    };
  };
}
