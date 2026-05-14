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

      # In VM builds, never touch Cloudflare: IPv4 NAT makes the update a no-op
      # on the same LAN, but the VM's own SLAAC IPv6 would clobber the AAAA
      # record with an address that disappears on shutdown.
      virtualisation.vmVariant.services.cloudflare-ddns.enable = lib.mkForce false;
    };
}
