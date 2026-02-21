{
  flake.nixosModules.prowlarr = _: {
    services.prowlarr = {
      enable = true;
      openFirewall = true;
    };
  };
}
