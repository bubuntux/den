{ self, ... }:
{
  flake.modules.nixos.sonarr =
    _:
    let
      port = 8989;
    in
    {
      key = "den:nixos.sonarr";
      imports = [ self.modules.nixos.media-registry ];

      services.sonarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      den.media.services.sonarr = {
        inherit port;
        umask = "0002";
        # sonarr.wg alias: prowlarr, inside the wg netns, dials the *arrs by name.
        namespace = "wg";
        # Sonarr's .NET runtime has been observed peaking at 1.28 GB during
        # library-wide refresh scans on appa, the largest non-immich consumer on
        # the host. Cap above peak so scans don't OOM, below 1/5 of RAM so a
        # runaway scan can't drown the box.
        resources = {
          memoryHigh = "12%";
          memoryMax = "18%";
          cpuWeight = 75;
          ioWeight = 75;
        };
      };

      services.reverse-proxy.routes.sonarr.aliases = [ "shows" ];
    };
}
