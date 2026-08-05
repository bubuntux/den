{ self, ... }:
{
  # Container-safe foundation: no bootloader, no networking, no secrets. The
  # machine-only additions live in bundles/host.nix as bundle-host.
  flake.modules = {
    nixos.bundle-base = {
      key = "den:nixos.bundle-base";
      imports = with self.modules.nixos; [
        fonts
        home-manager
        locale
        nix
      ];

      # Root's HOME is not the one ghostty's ssh-terminfo wrote into -- see
      # CLAUDE.md, "Choosing a terminal".
      environment.enableAllTerminfo = true;

      home-manager.sharedModules = with self.modules.homeManager; [
        bundle-base
      ];
    };

    homeManager.bundle-base =
      { pkgs, ... }:
      {
        key = "den:homeManager.bundle-base";
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
          (self.lib.nvtop pkgs)
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
