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

      # On-box alias so host-side services (sonarr, radarr, bazarr) can
      # dial prowlarr without hardcoding the namespace IP — the host can't
      # reach it at its own LAN IP (see qbittorrent.nix for the PREROUTING
      # / OUTPUT gotcha). Use `http://prowlarr.wg:9696` in the *arr UIs.
      networking.hosts.${config.vpnNamespaces.wg.namespaceAddress} = [ "prowlarr.wg" ];

      systemd.services.prowlarr.vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };

      # Resource caps (percent-of-RAM scales with hardware upgrades).
      # Smallest of the .NET *arrs — mostly idle, occasional indexer queries.
      # CPUWeight=75 matches sonarr/radarr.
      systemd.services.prowlarr.serviceConfig = {
        MemoryHigh = "4%";
        MemoryMax = "8%";
        CPUWeight = 75;
        IOWeight = 75;
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
