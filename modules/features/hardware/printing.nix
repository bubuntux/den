{
  flake.nixosModules.printing =
    { pkgs, ... }:
    {
      services = {
        printing = {
          enable = true;
          # webInterface = false;
          drivers = with pkgs; [
            cups-filters
            cups-browsed
            gutenprintBin
            epson-escpr
            epson-escpr2
            brlaser
            # TODO add brother printer
          ];
        };

        # TODO move?
        avahi = {
          enable = true;
          ipv4 = true;
          ipv6 = true;
          nssmdns4 = true;
          nssmdns6 = true;
          openFirewall = true;
        };

      };
    };
}
