{ self, ... }:
{
  flake.nixosModules.qbittorrent = _: {
    imports = [ self.nixosModules.vpn-confinement ];

    services.qbittorrent = {
      enable = true;
      # Exposure is handled by the vpn-media namespace's portMappings.
      openFirewall = false;
      webuiPort = 8080;
    };

    systemd.services.qbittorrent.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    vpnNamespaces.wg = {
      portMappings = [
        {
          from = 8080;
          to = 8080;
          protocol = "tcp";
        }
      ];

      # Inbound peer port. Pin the same value in the qbittorrent UI under
      # Connection → Port used for incoming connections.
      openVPNPorts = [
        {
          port = 60729;
          protocol = "both";
        }
      ];
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 8080;
        guest.port = 8080;
      }
    ];
  };
}
