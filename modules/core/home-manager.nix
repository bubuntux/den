{ inputs, self, ... }:
{

  flake-file.inputs.home-manager.url = "github:nix-community/home-manager";
  flake-file.inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake.nixosModules.home-manager =
    { ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bkp";
        sharedModules = [
          # Wrap in attrsets with explicit keys for deduplication when
          # this module is reached through multiple NixOS import paths
          {
            key = "homeModules.home-manager";
            imports = [ self.homeModules.home-manager ];
          }
        ];
      };
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
