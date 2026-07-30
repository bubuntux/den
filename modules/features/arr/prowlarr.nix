{ self, ... }:
{
  flake.modules.nixos.prowlarr =
    _:
    let
      port = 9696;
    in
    {
      key = "den:nixos.prowlarr";
      imports = with self.modules.nixos; [
        media-registry
        vpn-confinement
      ];

      services.prowlarr = {
        enable = true;
        # Exposure is handled by the vpn-confinement namespace's portMappings.
        openFirewall = false;
        settings.server.port = port;
      };

      den.media.services.prowlarr = {
        inherit port;
        # Runs inside the wg netns, so the prowlarr.wg alias and Caddy's upstream
        # both resolve to the namespace address rather than the bridge.
        namespace = "wg";
        inNamespace = true;
        # No media user or /mnt/media access: prowlarr only talks to indexers.
        mediaGroup = false;
        requiresMounts = [ ];
        # Smallest of the .NET *arrs -- mostly idle, occasional indexer queries.
        resources = {
          memoryHigh = "4%";
          memoryMax = "8%";
          cpuWeight = 75;
          ioWeight = 75;
        };
      };

      services.reverse-proxy.routes.prowlarr.aliases = [ "idx" ];

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
    };
}
