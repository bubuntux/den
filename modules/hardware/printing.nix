{
  flake.modules.nixos.printing =
    { pkgs, ... }:
    {
      key = "den:nixos.printing";
      services.printing = {
        enable = true;
        browsed.enable = false;
        drivers = with pkgs; [
          cups-filters
          gutenprintBin
          epson-escpr
          epson-escpr2
          brlaser
        ];
      };

      hardware.printers = {
        ensureDefaultPrinter = "Brother_HL_L3270CDW";
        ensurePrinters = [
          {
            name = "Brother_HL_L3270CDW";
            description = "Brother HL-L3270CDW";
            location = "home";
            # Bare hostname, not BRW30C9AB05985E.local: mDNS-over-NSS resolves
            # nothing here, so the name only comes back from the router's DNS.
            deviceUri = "ipp://BRW30C9AB05985E:631/ipp/print";
            model = "everywhere";
          }
        ];
      };
    };
}
