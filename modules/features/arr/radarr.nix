{
  flake.nixosModules.radarr = _: {
    services.radarr = {
      enable = true;
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 7878;
        guest.port = 7878;
      }
    ];
  };
}
