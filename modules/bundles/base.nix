{ self, ... }:
{
  flake.modules = {
    nixos.bundle-base = _: {
      imports = with self.modules.nixos; [
        fonts
        home-manager
        locale
        nix
      ];

      home-manager.sharedModules = with self.modules.homeManager; [
        bundle-base
      ];
    };

    nixos.bundle-host = _: {
      imports = with self.modules.nixos; [
        bundle-base
        auto-upgrade
        boot
        hardware-diagnostics
        networking
        sops
        sudors
        ntpdrs
        dirty-frag-mitigation
        zsh
      ];
    };

    homeManager.bundle-base =
      { pkgs, ... }:
      {
        imports = with self.modules.homeManager; [
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

  };
}
