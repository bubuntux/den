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
        # then builds relative URLs.
        baseUrl = "";
        passwordFile = config.sops.secrets.freshrss_password.path;
        api.enable = true;
        extensions = [
          # Reddit answers the post's .json with 403 to anonymous clients, so
          # v.redd.it videos are resolved from their HLS playlist instead, with
          # a script playing their separate audio track alongside.
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
        public = true;
        rateLimit.paths = [ "/api/greader.php/accounts/ClientLogin" ];
        # The login form posts to a query string, which `rateLimit.paths` cannot match.
        extraConfig = ''
          rate_limit {
            zone freshrss_form_login {
              match {
                method POST
                path /i/ /i/index.php
                query c=auth a=login
              }
              key {client_ip}
              events 5
              window 1m
            }
          }
        '';
      };

      systemd.services."phpfpm-${config.services.freshrss.pool}".serviceConfig = resources;
      systemd.services.freshrss-updater.serviceConfig = resources;
    };
}
