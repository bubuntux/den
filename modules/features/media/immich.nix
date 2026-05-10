{
  flake.nixosModules.immich = _: {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      mediaLocation = "/mnt/data/immich";
    };

    # Ensure the non-default mediaLocation exists with correct ownership.
    systemd.tmpfiles.rules = [
      "d /mnt/data/immich 0750 immich immich -"
    ];
  };
}
