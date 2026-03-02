{
  flake.nixosModules.bazarr = _: {
    services.bazarr = {
      enable = true;
      openFirewall = true;
    };
  };
}
