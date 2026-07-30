{ ... }:
{
  flake.modules.nixos.avahi = {
    key = "den:nixos.avahi";
    services.avahi = {
      enable = true;
      ipv4 = true;
      ipv6 = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };
  };
}
