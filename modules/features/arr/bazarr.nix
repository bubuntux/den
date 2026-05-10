{
  flake.nixosModules.bazarr = _: {
    services.bazarr = {
      enable = true;
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 6767;
        guest.port = 6767;
      }
    ];
  };
}
