{ self, ... }:
{
  flake.nixosModules.bundle-base = _: {
    imports = with self.nixosModules; [
      fonts
      home-manager
      locale
      nix
    ];

    home-manager.sharedModules = with self.homeModules; [
      bundle-base
    ];
  };

  flake.nixosModules.bundle-host = _: {
    imports = with self.nixosModules; [
      bundle-base
      auto-upgrade
      boot
      networking
      sops
      sudors
      ntpdrs
      dirty-frag-mitigation
      zsh
    ];
  };

  flake.homeModules.bundle-base =
    { pkgs, ... }:
    {
      imports = with self.homeModules; [
        home-manager
        fonts
        git
        helix
        ssh
      ];

      home.packages = with pkgs; [
        # File manager.
        ranger

        # Process monitoring
        bottom
        htop
        pv

        # Request/parsers
        httpie
        jq
        yq-go

        # Archives
        ouch
        p7zip
        rar
        unzip
        xz
        zip
      ];

      programs = {
        bash.enable = true;

        direnv = {
          enable = true;
          silent = true;
          nix-direnv.enable = true;
        };

        eza.enable = true;

        starship.enable = true;
      };
    };

}
