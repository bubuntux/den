{ self, ... }:
{
  flake.modules.nixos.radarr =
    _:
    let
      port = 7878;
    in
    {
      key = "den:nixos.radarr";
      imports = [ self.modules.nixos.media-registry ];

      services.radarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      # media group, UMask 0002, RequiresMountsFor /mnt/media, the resource caps,
      # the route's port, the VM forward and the radarr.wg alias all come from
      # den.media.services -- see features/media/registry.nix.
      den.media.services.radarr = {
        inherit port;
        umask = "0002";
        namespace = "wg";
        # Symmetric with Sonarr's .NET runtime -- observed peaks of ~560 MB with
        # a smaller library than Sonarr's.
        resources = {
          memoryHigh = "8%";
          memoryMax = "15%";
          cpuWeight = 75;
          ioWeight = 75;
        };
      };

      services.reverse-proxy.routes.radarr.aliases = [ "movies" ];
    };
}
