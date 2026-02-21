{
  flake.nixosModules.jellyfin = _: {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };
  };
}
