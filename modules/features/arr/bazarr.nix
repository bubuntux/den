{
  flake.nixosModules.bazarr =
    { config, ... }:
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
