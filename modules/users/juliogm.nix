{
  self,
  ...
}:
{
  # Home Manager module for user juliogm
  flake.homeModules.user-juliogm = {
    imports = with self.homeModules; [
      profile-developer
    ];
  };

  # NixOS module for user juliogm (used inside the work container)
  flake.nixosModules.user-juliogm = {
    users.users.juliogm = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [
        "audio"
        "network"
        "pipewire"
        "video"
        "wheel"
      ];
      home = "/home/juliogm";
      createHome = true;
    };

    home-manager.users.juliogm = {
      imports = [ self.homeModules.user-juliogm ];
    };
  };
}
