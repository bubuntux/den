{
  flake.nixosModules.cloudflare-ddns =
    { lib, ... }:
    {
      services.cloudflare-ddns = {
        enable = true;

        # Placeholder to satisfy the module assertion; actual domains come from the sops EnvironmentFile.
        domains = [ "placeholder.invalid" ];

        # TODO: Use config.sops.secrets.cloudflare_ddns.path once sops is configured for appa.
        # The sops secret should be an EnvironmentFile containing:
        #   CLOUDFLARE_API_TOKEN=your_token
        #   DOMAINS=example.com,*.example.com
        #   PROXIED=false
        #   UPDATE_CRON=@every 5m
        #   UPDATE_ON_START=true
        #   DELETE_ON_STOP=false
        #   TTL=1
        #   IP4_PROVIDER=cloudflare.trace
        #   IP6_PROVIDER=cloudflare.trace
        #   DETECTION_TIMEOUT=5s
        #   UPDATE_TIMEOUT=30s
        #   CACHE_EXPIRATION=6h
        credentialsFile = "/run/secrets/cloudflare_ddns";
      };

      # Clear module-generated Environment so all config comes from the sops EnvironmentFile.
      # The NixOS module sets Environment= entries that take precedence over EnvironmentFile=.
      systemd.services.cloudflare-ddns.serviceConfig.Environment = lib.mkForce [ ];
    };
}
