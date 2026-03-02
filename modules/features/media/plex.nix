{
  flake.nixosModules.plex = _: {
    services.plex = {
      enable = true;
      openFirewall = true;
    };
  };
}
