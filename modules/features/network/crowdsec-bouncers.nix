{
  flake.nixosModules.crowdsec-bouncers = _: {
    # Firewall bouncer: drops banned IPs at the nftables layer. Protocol-
    # agnostic — catches port scans, SSH brute force, and anything else that
    # never touches Caddy. registerBouncer.enable wires it up to the local
    # agent at activation time; no manual cscli step needed for this one.
    #
    # Depends on the crowdsec agent being enabled elsewhere — profile-nas
    # imports `crowdsec` alongside `crowdsec-bouncers` so the agent is
    # listening on 127.0.0.1:6060 when this bouncer starts.
    services.crowdsec-firewall-bouncer = {
      enable = true;
      registerBouncer.enable = true;

      # Point at the relocated CrowdSec API (see crowdsec.nix for why 6060).
      settings.api_url = "http://127.0.0.1:6060";
    };

    # Caddy bouncer (HTTP-layer enforcement) cannot auto-register through
    # NixOS, so the key has to be minted manually on `appa` once:
    #
    #   sudo cscli bouncers add caddy -o raw
    #
    # then pasted into the existing `caddy_env` sops entry as
    # `CROWDSEC_CADDY_API_KEY=...` alongside BASE_DOMAIN / CLOUDFLARE_API_TOKEN
    # / ACME_EMAIL. The bouncer plugin reads the env var at Caddy startup.
    # See reverse-proxy.nix for the Caddyfile wiring.
  };
}
