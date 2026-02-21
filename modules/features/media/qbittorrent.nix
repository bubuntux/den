{
  flake.nixosModules.qbittorrent = _: {
    services.qbittorrent = {
      enable = true;
      openFirewall = true;
      webuiPort = 8080;
    };
  };
}
