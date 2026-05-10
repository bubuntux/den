{
  flake.nixosModules.sonarr = _: {
    services.sonarr = {
      enable = true;
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 8989;
        guest.port = 8989;
      }
    ];
  };
}
