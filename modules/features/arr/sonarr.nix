{
  flake.nixosModules.sonarr = _: {
    services.sonarr = {
      enable = true;
      openFirewall = true;
    };
  };
}
