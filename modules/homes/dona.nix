{
  flake.nixosModules.dona = {
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
