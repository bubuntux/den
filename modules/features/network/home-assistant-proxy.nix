{
  flake.modules.nixos.home-assistant-proxy =
    _:
    # HA runs on a separate appliance; this only publishes the caddy route, so
    # it gets the same wildcard cert and LAN-only gating as the *arr UIs.
    # WebSockets need no extra config -- caddy upgrades them itself.
    #
    # Required on the HA box, not enforceable from here:
    #   http: { use_x_forwarded_for: true, trusted_proxies: [<appa LAN IPv4>] }
    # Without it every client shows up as the caddy host.
    {
      key = "den:nixos.home-assistant-proxy";
      services.reverse-proxy.routes.home-assistant = {
        port = 8123;
        upstreamAddr = "192.168.5.2";
        aliases = [
          "ha"
          "home"
          "homeassistant"
        ];
        public = true;
        # HA's auth endpoints are the obvious brute-force target once this is
        # internet-reachable. 5/IP/min mirrors the jellyfin pattern; legitimate
        # users tripping it just means waiting a minute. /auth/* covers both
        # the login flow and the long-lived token issuer.
        rateLimit.paths = [ "/auth/*" ];
      };

      # HA is not on appa, so detection happens at the caddy layer instead:
      # http-generic-401-bf fires on repeated 401s in the access log. No hub pin
      # -- that scenario ships inside http-generic-bf.yaml, which comes in with
      # base-http-scenarios, and there is no hub item by its own name.
    };
}
