{
  flake.nixosModules.immich = _: {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 2283;
        guest.port = 2283;
      }
    ];
  };
}
