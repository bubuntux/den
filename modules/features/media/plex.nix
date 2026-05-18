{
  flake.nixosModules.plex =
    _:
    # Upstream services.plex module has no port option; 32400 is the Plex
    # Media Server's hard-coded web port.
    let
      port = 32400;
    in
    {
      services.plex = {
        enable = true;
        openFirewall = true;
      };

      # `render` owns /dev/dri/renderD128 (GPU compute / VA-API), `video` owns
      # the legacy card0 node. Required for Plex Pass hardware transcoding to
      # find the iGPU; without these groups the transcoder probe fails
      # silently and Plex falls back to software encoding.
      users.users.plex.extraGroups = [
        "render"
        "video"
      ];

      # Allowlist for Plex's own infrastructure (Plex Relay, metadata) so
      # legitimate Plex traffic doesn't get flagged. No acquisition needed
      # — this collection only ships a parser that whitelists known IPs.
      services.crowdsec.hub.collections = [ "crowdsecurity/plex" ];

      services.reverse-proxy.routes.plex = {
        inherit port;
        aliases = [ "px" ];
        public = true;
        # Disable response buffering so streaming starts responding to the
        # client immediately (matters for video seek / first-frame latency).
        proxyConfig = ''
          flush_interval -1
        '';
      };

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
