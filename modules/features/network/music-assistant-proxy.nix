{
  flake.modules.nixos.music-assistant-proxy =
    _:
    # Music Assistant runs as an add-on on the HA appliance; this only publishes
    # the caddy route. 8095 is its own authenticated webserver -- the add-on's
    # ingress site (8094) skips auth and is bound to HA's docker network only.
    {
      key = "den:nixos.music-assistant-proxy";
      services.reverse-proxy.routes.music-assistant = {
        port = 8095;
        upstreamAddr = "192.168.5.2";
        aliases = [
          "ma"
          "music"
        ];
        public = true;
        # Only the login POST: the rest of /auth/* (me, providers, callback) is
        # hit on every page load and would trip a 5/min limit.
        rateLimit.paths = [ "/auth/login" ];
      };
    };
}
