{
  flake.nixosModules.home-assistant-proxy =
    _:
    # Home Assistant runs on a separate appliance at 192.168.5.2:8123 (not
    # managed by this flake). This module just publishes a caddy route so
    # ha.<base-domain> resolves on the LAN and goes through the same wildcard
    # TLS cert / LAN-only gating as the rest of the *arr admin UIs.
    #
    # Caddy v2's reverse_proxy auto-upgrades WebSocket connections, which HA's
    # frontend relies on -- no extra proxyConfig needed.
    #
    # Counterpart config required on the HA box (not enforceable from here):
    #   http:
    #     use_x_forwarded_for: true
    #     trusted_proxies:
    #       - <appa LAN IPv4>
    # Without this, HA rejects the X-Forwarded-* headers and the UI shows
    # every client as the caddy host's IP.
    {
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

      # HA itself isn't on appa, so journald-based acquisitions aren't an
      # option. The detection lives at the caddy layer: every request hits
      # caddy access logs (already tailed via crowdsecurity/caddy), and
      # LePresidente/http-generic-401-bf fires after repeated 401s on
      # /auth/* -- verified via `cscli explain` against a simulated log
      # line. Pin it here as a direct dependency so the HA protection
      # doesn't silently disappear if some other module that pulled it in
      # transitively (LePresidente/jellyfin) is ever removed.
      services.crowdsec.hub.scenarios = [ "LePresidente/http-generic-401-bf" ];
    };
}
