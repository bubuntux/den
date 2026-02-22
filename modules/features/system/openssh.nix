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
  };
}
