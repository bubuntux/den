{ inputs, self, ... }:
{
  # flake.homeModules.user-dona = {
  #   imports = [ self.homeModules.bundle-base ];
  #   # home.stateVersion = "25.11";
  # };

  flake.nixosModules.user-dona = {
    services.displayManager.autoLogin.user = "dona";
    users.users.dona = {
      isNormalUser = true;
      description = "Dona";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
    home-manager.users.dona = {
      # imports = [ self.homeModules.user-dona ];
    };
  };

  # flake.homeConfigurations.dona = inputs.home-manager.lib.homeManagerConfiguration {
  #   pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  #   modules = [
  #     self.homeModules.user-dona
  #     {
  #       home.username = "dona";
  #       home.homeDirectory = "/home/dona";
  #     }
  #   ];
  # };
}
