{
  flake.nixosModules.plex = _: {
    services.plex = {
      enable = true;
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 32400;
        guest.port = 32400;
      }
    ];
  };
}
