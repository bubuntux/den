{ self, ... }:
{
  flake.modules.nixos.prowlarr =
    _:
    let
      port = 9696;
    in
    {
      key = "den:nixos.prowlarr";
      imports = [ self.modules.nixos.media-registry ];

      services.prowlarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      den.media.services.prowlarr = {
        inherit port;
        namespace = "wg";
        # No media user or /mnt/media access: prowlarr only talks to indexers.
        mediaGroup = false;
        requiresMounts = [ ];
        resources = {
          memoryHigh = "4%";
          memoryMax = "8%";
          cpuWeight = 75;
          ioWeight = 75;
        };
      };

      services.reverse-proxy.routes.prowlarr.aliases = [ "idx" ];
    };
}
