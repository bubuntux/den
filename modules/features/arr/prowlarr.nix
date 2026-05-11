{ self, ... }:
{
  flake.nixosModules.prowlarr = _: {
    imports = [ self.nixosModules.vpn-confinement ];

    services.prowlarr = {
      enable = true;
      # Exposure is handled by the vpn-media namespace's portMappings.
      openFirewall = false;
    };

    systemd.services.prowlarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    vpnNamespaces.wg.portMappings = [
      {
        from = 9696;
        to = 9696;
        protocol = "tcp";
      }
    ];

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 9696;
        guest.port = 9696;
      }
    ];
  };
}
