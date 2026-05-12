{ self, ... }:
{
  flake.nixosModules.cloudflare-ddns =
    { config, lib, ... }:
    {
      imports = [ self.nixosModules.sops ];

      sops.secrets.cloudflare_ddns = {
        sopsFile = "${self}/secrets/appa.yaml";
        restartUnits = [ "cloudflare-ddns.service" ];
      };

      services.cloudflare-ddns = {
        enable = true;

        # Placeholder to satisfy the module assertion; actual domains come from the sops EnvironmentFile.
        domains = [ "placeholder.invalid" ];

        credentialsFile = config.sops.secrets.cloudflare_ddns.path;
      };

      # Clear module-generated Environment so all config comes from the sops EnvironmentFile.
      # The NixOS module sets Environment= entries that take precedence over EnvironmentFile=.
      systemd.services.cloudflare-ddns.serviceConfig.Environment = lib.mkForce [ ];
    };
}
