{ self, ... }:
{
  flake.nixosModules.prowlarr =
    { config, ... }:
    let
      port = 9696;
    in
    {
      imports = [ self.nixosModules.vpn-confinement ];

      services.prowlarr = {
        enable = true;
        # Exposure is handled by the vpn-confinement namespace's portMappings.
        openFirewall = false;
        settings.server.port = port;
      };

      services.reverse-proxy.routes.prowlarr = {
        inherit port;
        # See qbittorrent.nix for why we dial the namespace veth IP rather
        # than 127.0.0.1.
        upstreamAddr = config.vpnNamespaces.wg.namespaceAddress;
        aliases = [ "idx" ];
      };

      systemd.services.prowlarr.vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };

      vpnNamespaces.wg.portMappings = [
        {
          from = port;
          to = port;
          protocol = "tcp";
        }
      ];

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
