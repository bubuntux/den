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
          (callPackage ./_cups-brother-hll3270cdw.nix { })
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
            # Raw 9100, not ipp://: the vendor driver emits PJL, which is what
            # JetDirect expects; the printer's IPP endpoint takes only raster.
            deviceUri = "socket://BRW30C9AB05985E:9100";
            # A PPD from the driver package, not "everywhere": the latter makes
            # lpadmin fetch capabilities from the printer, so the queue would
            # only build while on the home LAN -- and a failed fetch deletes
            # the existing queue.
            model = "brother_hll3270cdw_printer_en.ppd";
          }
        ];
      };
    };
}
