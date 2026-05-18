{ self, ... }:
{
  flake.nixosModules.openssh =
    { lib, ... }:
    {
      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      networking.firewall.extraInputRules = ''
        ip saddr { ${lib.concatStringsSep ", " self.lib.lan.ipv4} } tcp dport 22 accept
        ip6 saddr { ${lib.concatStringsSep ", " self.lib.lan.ipv6} } tcp dport 22 accept
      '';

      # SSH brute-force / scan detection. The s00-raw parser sets program
      # from labels.type for non-syslog inputs, so type must match the
      # crowdsecurity/sshd-logs filter (program in ['sshd', 'sshd-session']).
      services.crowdsec.hub.collections = [ "crowdsecurity/sshd" ];
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "sshd";
        }
      ];

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
}
