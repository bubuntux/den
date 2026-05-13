{
  flake.nixosModules.jellyfin =
    _:
    # Upstream services.jellyfin module has no port option; these are the
    # hard-coded HTTP/HTTPS ports baked into the Jellyfin binary.
    let
      port = 8096;
      httpsPort = 8920;
    in
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      services.reverse-proxy.routes.jellyfin = {
        inherit port;
        aliases = [
          "jf"
          "media"
        ];
        public = true;
        # Disable response buffering so streaming starts responding to the
        # client immediately (matters for video seek / first-frame latency).
        proxyConfig = ''
          flush_interval -1
        '';
      };

      virtualisation.vmVariant.virtualisation = {
        # Jellyfin 10.10+ refuses to start with <2 GiB free at its data dir.
        # In production the data lives on /mnt/data; in the VM it falls back to /.
        diskSize = 4096;

        forwardPorts = [
          {
            from = "host";
            host.port = port;
            guest.port = port;
          }
          {
            from = "host";
            host.port = httpsPort;
            guest.port = httpsPort;
          }
        ];
      };
    };
}
