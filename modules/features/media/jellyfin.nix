{
  flake.nixosModules.jellyfin = _: {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    virtualisation.vmVariant.virtualisation = {
      # Jellyfin 10.10+ refuses to start with <2 GiB free at its data dir.
      # In production the data lives on /mnt/data; in the VM it falls back to /.
      diskSize = 4096;

      forwardPorts = [
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
  };
}
