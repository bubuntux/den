{
  flake.nixosModules.crowdsec-bouncers =
    { config, pkgs, ... }:
    {
      # Firewall bouncer: drops banned IPs at the nftables layer. Protocol-
      # agnostic — catches port scans, SSH brute force, and anything else
      # that never touches Caddy. registerBouncer.enable wires it up to the
      # local agent at activation time; no manual cscli step needed.
      #
      # Depends on the crowdsec agent being enabled elsewhere — profile-nas
      # imports `crowdsec` alongside `crowdsec-bouncers`.
      services.crowdsec-firewall-bouncer = {
        enable = true;
        registerBouncer.enable = true;

        # Point at the relocated CrowdSec API (see crowdsec.nix for why 6868).
        settings.api_url = "http://127.0.0.1:6868";
      };

      # Upstream sets Requires= but not After= for the register service, so
      # on first boot the bouncer can race past it and fail to LoadCredential
      # the API key the register hasn't written yet. Add the explicit
      # ordering so the bouncer waits for the register oneshot to finish.
      systemd.services.crowdsec-firewall-bouncer.after = [
        "crowdsec-firewall-bouncer-register.service"
      ];

      # Caddy bouncer auto-register. The bouncer plugin in Caddy doesn't
      # have a NixOS-side helper like the firewall bouncer does, so we
      # mint the bouncer ourselves using whatever key the user put into
      # `caddy_env` (CROWDSEC_CADDY_API_KEY). Idempotent. Raw cscli works
      # here because crowdsec.nix provides /etc/crowdsec/config.yaml,
      # which is the default config path cscli looks for.
      systemd.services.crowdsec-caddy-register = {
        description = "Register Caddy bouncer with the local CrowdSec agent";
        after = [ "crowdsec.service" ];
        wants = [ "crowdsec.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = config.sops.secrets.caddy_env.path;
        };
        path = [
          config.services.crowdsec.package
          pkgs.jq
        ];
        script = ''
          if [ -z "''${CROWDSEC_CADDY_API_KEY:-}" ]; then
            echo "CROWDSEC_CADDY_API_KEY unset; skipping registration"
            exit 0
          fi
          if cscli bouncers list -o json | jq -e '.[] | select(.name == "caddy")' >/dev/null 2>&1; then
            echo "caddy bouncer already registered; skipping"
            exit 0
          fi
          cscli bouncers add caddy -k "$CROWDSEC_CADDY_API_KEY"
        '';
      };

      # Make sure caddy doesn't start before the bouncer key is registered;
      # otherwise its first auth handshake against the local API fails and
      # the plugin falls back to fail-open until next poll.
      systemd.services.caddy = {
        after = [ "crowdsec-caddy-register.service" ];
        wants = [ "crowdsec-caddy-register.service" ];
      };
    };
}
