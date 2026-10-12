{ self, ... }:
{
  flake.modules.nixos.freshrss =
    { config, pkgs, ... }:
    let
      port = 8085;
      resources = {
        MemoryHigh = "5%";
        MemoryMax = "10%";
        CPUWeight = 50;
        IOWeight = 50;
      };
    in
    {
      key = "den:nixos.freshrss";
      imports = [
        self.modules.nixos.reverse-proxy
        self.modules.nixos.sops
      ];

      sops.secrets.freshrss_password = {
        sopsFile = "${self}/secrets/appa.yaml";
        owner = config.services.freshrss.user;
        restartUnits = [ "freshrss-config.service" ];
      };

      services.freshrss = {
        enable = true;
        # Empty, because the domain only exists in the sops env file; FreshRSS
        # then builds relative URLs, which is all a LAN-only instance needs.
        baseUrl = "";
        passwordFile = config.sops.secrets.freshrss_password.path;
        api.enable = true;
        extensions = [
          # Reddit answers the post's .json with 403 to anonymous clients, so
          # v.redd.it videos are resolved from their HLS playlist instead.
          (pkgs.freshrss-extensions.reddit-image.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./reddit-image-hls-video.patch ];
          }))
        ];
        webserver = "caddy";
        # Caddy proxies to itself: the wildcard site in reverse-proxy.nix keeps
        # the TLS, CrowdSec and LAN filtering, and this one only speaks FastCGI.
        virtualHost = "http://:${toString port}";
      };

      services.caddy.virtualHosts.${config.services.freshrss.virtualHost} = {
        listenAddresses = [ "127.0.0.1" ];
        logFormat = "output discard";
      };

      services.reverse-proxy.routes.freshrss = {
        inherit port;
        aliases = [ "rss" ];
      };

      systemd.services."phpfpm-${config.services.freshrss.pool}".serviceConfig = resources;
      systemd.services.freshrss-updater.serviceConfig = resources;
    };
}
