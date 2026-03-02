{ self, ... }:
{
  flake.nixosModules.printing =
    { pkgs, ... }:
    let
      cups-brother-hll3270cdw = pkgs.callPackage "${self}/pkgs/cups-brother-hll3270cdw.nix" { };
    in
    {
      services.printing = {
        enable = true;
        browsed.enable = true;
        drivers = with pkgs; [
          cups-filters
          gutenprintBin
          epson-escpr
          epson-escpr2
          brlaser
          cups-brother-hll3270cdw
        ];
      };
    };
}
