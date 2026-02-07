{ inputs, self, ... }:
{
  flake.nixosModules.home-dona = {
    services.displayManager.autoLogin.user = "dona";
    users.users.dona = {
      isNormalUser = true;
      description = "Dona";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
  };

  flake.homeConfigurations.dona = inputs.home-manager.lib.homeManagerConfiguration {
    modules = [
      self.homeModules.profile-base
    ];
  };

}
