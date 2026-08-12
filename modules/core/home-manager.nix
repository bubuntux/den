{ inputs, self, ... }:
{

  flake-file.inputs.home-manager.url = "github:nix-community/home-manager/release-26.05";
  flake-file.inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  flake-file.inputs.home-manager-unstable.url = "github:nix-community/home-manager";
  flake-file.inputs.home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs";

  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake.modules = {
    nixos.home-manager =
      { ... }:
      {
        key = "den:nixos.home-manager";
        imports = [ inputs.home-manager.nixosModules.home-manager ];
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bkp";
          sharedModules = [ self.modules.homeManager.home-manager ];
        };
      };

    homeManager.home-manager = {
      key = "den:homeManager.home-manager";
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
  };
}
