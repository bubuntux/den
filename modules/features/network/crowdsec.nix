{ self, ... }:
{
  flake.nixosModules.crowdsec =
    { config, ... }:
    {
      imports = [ self.nixosModules.sops ];

      # Console enrollment key (optional). Add to secrets/appa.yaml:
      #
      #   crowdsec_console_key: "<from cscli console enroll on app.crowdsec.net>"
      #
      # An empty string is also fine — the systemd unit below skips
      # enrollment when the value is blank, so hosts without a Console
      # account can still build cleanly.
      sops.secrets.crowdsec_console_key = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      services.crowdsec = {
        enable = true;
        # `cscli hub update` runs daily so parser / scenario / blocklist
        # definitions stay current.
        autoUpdateService = true;

        # CrowdSec's default API port (8080) collides with qbittorrent's
        # webuiPort, so move it to 6060. The firewall bouncer and the Caddy
        # bouncer both pick this up.
        settings.general.api.server.listen_uri = "127.0.0.1:6060";

        # Generic collections that aren't tied to one specific service.
        # Per-service collections + acquisitions live in the service module
        # that produces the logs (see e.g. reverse-proxy.nix for caddy,
        # openssh.nix for sshd, jellyfin.nix / forgejo.nix / plex.nix for
        # their app-specific parsers).
        hub.collections = [
          "crowdsecurity/linux"
          "crowdsecurity/base-http-scenarios"
          "crowdsecurity/http-cve"
          "crowdsecurity/http-dos"
          "crowdsecurity/whitelist-good-actors"
        ];

        # Whitelist trusted local networks so internal traffic never gets
        # banned, even if a misconfigured app triggers an HTTP scenario.
        localConfig.parsers.s02Enrich = [
          {
            name = "den/lan-whitelist";
            description = "Trust local networks";
            whitelist = {
              reason = "trusted LAN ranges";
              ip = [ "127.0.0.1" ];
              cidr = [
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/16"
              ];
            };
          }
        ];
      };

      # Console enrollment is idempotent in spirit but cscli prompts if
      # already enrolled, so we skip when local_api_credentials shows a
      # login. The user still has to approve the agent in the Console UI
      # once — this just kicks the request automatically.
      systemd.services.crowdsec-console-enroll = {
        description = "Enroll the local agent with the CrowdSec Console";
        after = [ "crowdsec.service" ];
        wants = [ "crowdsec.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ config.services.crowdsec.package ];
        script = ''
          key=$(cat ${config.sops.secrets.crowdsec_console_key.path})
          if [ -z "$key" ]; then
            echo "no console key configured; skipping enrollment"
            exit 0
          fi
          if [ -e /etc/crowdsec/online_api_credentials.yaml ] \
             && grep -q '^login:' /etc/crowdsec/online_api_credentials.yaml; then
            echo "already enrolled with the Console; skipping"
            exit 0
          fi
          cscli console enroll "$key"
        '';
      };
    };
}
