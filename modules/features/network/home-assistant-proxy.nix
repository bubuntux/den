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
        aliases = [ "ha" ];
        # public defaults to false -- LAN-only.
      };
    };
}
