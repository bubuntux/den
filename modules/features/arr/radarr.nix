{
  flake.nixosModules.radarr = _: {
    services.radarr = {
      enable = true;
      openFirewall = true;
    };
  };
}
