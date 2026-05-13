{
  flake.nixosModules.crowdsec = _: {
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
  };
}
