{
  flake.nixosModules.home-dona = {
    users.users.dona = {
      isNormalUser = true;
      description = "Dona";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
  };
}
