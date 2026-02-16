{
  flake.nixosModules.printing =
    { pkgs, ... }:
    let
      cups-brother-hll3270cdw = pkgs.callPackage ../../../pkgs/cups-brother-hll3270cdw.nix { };
    in
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
            cups-brother-hll3270cdw
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
