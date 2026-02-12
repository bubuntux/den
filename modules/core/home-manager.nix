{ inputs, self, ... }:
{

  flake-file.inputs.home-manager.url = "github:nix-community/home-manager";

  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake.nixosModules.home-manager = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bkp";
      sharedModules = [ self.homeModules.home-manager ];
    };
  };

  flake.homeModules.home-manager = {
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
