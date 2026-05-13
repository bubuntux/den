{
  flake.nixosModules.openssh = _: {
    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking.firewall.extraInputRules = ''
      ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } tcp dport 22 accept
      ip6 saddr { fe80::/10, fd00::/8 } tcp dport 22 accept
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
