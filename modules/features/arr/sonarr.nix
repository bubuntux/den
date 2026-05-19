{
  flake.nixosModules.sonarr =
    { config, lib, ... }:
    let
      port = 8989;
    in
    {
      services.sonarr = {
        enable = true;
        openFirewall = true;
        settings.server.port = port;
      };

      users.users.sonarr.extraGroups = [ "media" ];

      # 0002 so files/dirs sonarr creates under /mnt/media keep group
      # write -- needed for radarr/bazarr/qbittorrent (all in the media
      # group) to manage the same trees.
      systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";

      services.reverse-proxy.routes.sonarr = {
        inherit port;
        aliases = [
          "tv"
          "shows"
        ];
      };

      # .wg alias so prowlarr (inside the wg netns) can dial us by name —
      # /etc/hosts is shared with the namespace because systemd's
      # NetworkNamespacePath only switches the net ns, not the mount ns.
      # Implicit dep: a host using this module must also import
      # vpn-confinement (true on appa via profile-nas).
      networking.hosts.${config.vpnNamespaces.wg.bridgeAddress} = [ "sonarr.wg" ];

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
