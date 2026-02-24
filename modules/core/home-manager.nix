{ inputs, self, ... }:
{

  flake-file.inputs.home-manager.url = "github:nix-community/home-manager";
  flake-file.inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

  # Unstable nixpkgs for Home Manager user packages
  flake-file.inputs.nixpkgs-unstable.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake.nixosModules.home-manager =
    { pkgs, config, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bkp";
        extraSpecialArgs = {
          unstablePkgs = import inputs.nixpkgs-unstable {
            system = pkgs.stdenv.hostPlatform.system;
            config = config.nixpkgs.config;
          };
        };
        sharedModules = [
          # Wrap in attrsets with explicit keys for deduplication when
          # this module is reached through multiple NixOS import paths
          {
            key = "homeModules.home-manager";
            imports = [ self.homeModules.home-manager ];
          }
          {
            key = "homeModules.unstable-pkgs";
            imports = [ self.homeModules.unstable-pkgs ];
          }
        ];
      };
    };

  # Override HM pkgs with unstable nixpkgs
  flake.homeModules.unstable-pkgs =
    { lib, unstablePkgs, ... }:
    {
      _module.args.pkgs = lib.mkForce unstablePkgs;
      home.enableNixpkgsReleaseCheck = false;
    };

  flake.homeModules.home-manager = _: {
    home.stateVersion = "25.11";
    programs.home-manager.enable = true;
    services.home-manager.autoExpire = {
      enable = true;
      frequency = "weekly";
      timestamp = "-30 days";
      store = {
        cleanup = true;
        options = "--delete-older-than 30d";
      };
    };
  };
}
