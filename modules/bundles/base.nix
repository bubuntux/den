{ self, ... }:
{
  flake.nixosModules.bundle-base = {
    imports = with self.nixosModules; [
      auto-upgrade
      boot
      fonts
      home-manager
      locale
      networking
      nix
    ];

    home-manager.sharedModules = with self.homeModules; [
      bundle-base
    ];
  };

  flake.homeModules.bundle-base =
    { pkgs, ... }:
    {
      imports = with self.homeModules; [
        fonts
        git
        helix
        neovim
        ssh
      ];

      home.packages = with pkgs; [
        # File manager
        ranger

        # Process monitoring
        bottom
        htop

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
