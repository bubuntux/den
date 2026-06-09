{ self, ... }:
let
  okularDefaults = builtins.listToAttrs (
    map
      (m: {
        name = m;
        value = "okularApplication_pdf.desktop";
      })
      [
        "application/pdf"
        "application/x-gzpdf"
        "application/x-bzpdf"
        "application/x-wwf"
      ]
    ++ map (m: {
      name = m;
      value = "okularApplication_epub.desktop";
    }) [ "application/epub+zip" ]
    ++
      map
        (m: {
          name = m;
          value = "okularApplication_comicbook.desktop";
        })
        [
          "application/x-cbz"
          "application/x-cbr"
          "application/x-cbt"
          "application/x-cb7"
        ]
    ++
      map
        (m: {
          name = m;
          value = "okularApplication_ghostview.desktop";
        })
        [
          "application/postscript"
          "application/x-gzpostscript"
          "application/x-bzpostscript"
          "image/x-eps"
          "image/x-gzeps"
          "image/x-bzeps"
        ]
    ++ map (m: {
      name = m;
      value = "okularApplication_djvu.desktop";
    }) [ "image/vnd.djvu" ]
    ++ map (m: {
      name = m;
      value = "okularApplication_mobi.desktop";
    }) [ "application/x-mobipocket-ebook" ]
    ++ map (m: {
      name = m;
      value = "okularApplication_fb.desktop";
    }) [ "application/x-fictionbook+xml" ]
    ++
      map
        (m: {
          name = m;
          value = "okularApplication_xps.desktop";
        })
        [
          "application/oxps"
          "application/vnd.ms-xpsdocument"
        ]
  );
in
{
  # Home Manager module for desktop environments
  flake.homeModules.bundle-desktop =
    { pkgs, ... }:
    {
      imports = with self.homeModules; [
        mpv
        templates
        xdg
      ];

      targets.genericLinux.enable = true;
      services.network-manager-applet.enable = true;

      xdg.mimeApps.defaultApplications = okularDefaults;

      # Desktop packages
      home.packages = with pkgs; [
        kdePackages.okular # PDF viewer
        # Drop already-applied 5.11 patch; revert once unstable channel passes NixOS/nixpkgs@8927bc2ba3.
        qalculate-gtk # Calculator
        loupe # Image viewer
        pwvucontrol # PipeWire volume control
        qpwgraph # PipeWire patchbay (route audio to multiple devices)
        gimp-with-plugins # image editor
        simple-scan # scanner
        tidal-hifi # music streaming
      ];
    };

  # NixOS module for desktop environments
  flake.nixosModules.bundle-desktop = _: {
    imports = with self.nixosModules; [
      bundle-host
      theme
    ];

    # Enable networking
    networking.networkmanager.enable = true;

    # Disable NixOS Manual
    documentation.nixos.enable = false;

    # Add home-manager bundle-desktop module to shared modules
    home-manager.sharedModules = [ self.homeModules.bundle-desktop ];
  };
}
