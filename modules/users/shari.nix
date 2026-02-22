{ inputs, self, ... }:
{
  # flake.homeModules.user-shari = {
  #   imports = [ self.homeModules.bundle-base ];
  #   # home.stateVersion = "25.11";
  # };

  flake.nixosModules.user-shari = _: {
    services.displayManager.autoLogin.user = "shari";
    users.users.shari = {
      isNormalUser = true;
      description = "Sharai C";
      initialPassword = "shari";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfnT06gNHha8xJzYX7aFrszzdKraUp2Dv7iJvCNuBOE"
      ];
    };
    home-manager.users.shari = {
      # imports = [ self.homeModules.user-shari ];
    };
  };

  # flake.homeConfigurations.shari = inputs.home-manager.lib.homeManagerConfiguration {
  #   pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  #   modules = [
  #     self.homeModules.user-shari
  #     {
  #       home.username = "shari";
  #       home.homeDirectory = "/home/shari";
  #     }
  #   ];
  # };
}
