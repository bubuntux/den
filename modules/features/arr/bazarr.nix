{ self, ... }:
{
  flake.modules.nixos.bazarr =
    _:
    let
      port = 6767;
    in
    {
      key = "den:nixos.bazarr";
      imports = [ self.modules.nixos.media-registry ];

      services.bazarr = {
        enable = true;
        openFirewall = true;
        listenPort = port;
      };

      den.media.services.bazarr = {
        inherit port;
        # 0002 so subtitle files bazarr writes alongside media land 0664 and
        # remain editable by radarr/sonarr (also in the media group).
        umask = "0002";
        namespace = "wg";
        # Python; modest steady-state. CPUWeight=50 -- background subtitle
        # downloads should always yield to interactive streams.
        resources = {
          memoryHigh = "4%";
          memoryMax = "8%";
          cpuWeight = 50;
          ioWeight = 50;
        };
      };

      services.reverse-proxy.routes.bazarr.aliases = [ "subs" ];
    };
}
