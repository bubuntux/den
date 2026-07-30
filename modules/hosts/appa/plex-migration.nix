{ ... }:
{
  # Transitional: shims that let the NixOS plex service adopt state written by
  # the old Fedora CoreOS container setup. Both binds go away once the library
  # locations are remapped through the Plex UI -- at which point this whole file
  # can be deleted, which is why it is a file and not a stanza in storage.nix.
  flake.modules.nixos.appa = {
    key = "den:nixos.appa#plex-migration";

    # lsio container's /config volume root was /mnt/config/plex. Plex's
    # data lives at Library/Application Support/Plex Media Server/ inside
    # it. NixOS plex looks at $PLEX_DATADIR/Plex Media Server/, so bind
    # dataDir to the FCOS parent of "Plex Media Server".
    fileSystems."/var/lib/plex" = {
      device = "/mnt/config/plex/Library/Application Support";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };

    # Container-media-path shim. library.db section_locations reference
    # /data/{movies,tv,music,audiobooks,videos}. Remove this bind after
    # the library locations are remapped via Plex UI to /mnt/media/*.
    fileSystems."/data" = {
      device = "/mnt/media";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };

    systemd.services.plex.unitConfig.RequiresMountsFor = [
      "/var/lib/plex"
      "/data"
    ];
  };
}
