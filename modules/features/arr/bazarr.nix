{
  flake.nixosModules.bazarr =
    { config, lib, ... }:
    let
      port = 6767;
    in
    {
      services.bazarr = {
        enable = true;
        openFirewall = true;
        listenPort = port;
      };

      users.users.bazarr.extraGroups = [ "media" ];

      # 0002 so subtitle files bazarr writes alongside media land 0664
      # and remain editable by radarr/sonarr (also in the media group).
      systemd.services.bazarr.serviceConfig.UMask = lib.mkForce "0002";

      services.reverse-proxy.routes.bazarr = {
        inherit port;
        aliases = [ "subs" ];
      };

      # .wg alias so prowlarr (inside the wg netns) can dial us by name —
      # see sonarr.nix for the full rationale.
      networking.hosts.${config.vpnNamespaces.wg.bridgeAddress} = [ "bazarr.wg" ];

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
