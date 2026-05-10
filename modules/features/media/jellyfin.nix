{
  flake.nixosModules.jellyfin = _: {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 8096;
        guest.port = 8096;
      }
      {
        from = "host";
        host.port = 8920;
        guest.port = 8920;
      }
    ];
  };
}
