{
  flake.nixosModules.printing =
    { pkgs, ... }:
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
        ];
      };
    };
}
