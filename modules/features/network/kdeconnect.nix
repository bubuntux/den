{ self, ... }:
{
  flake.nixosModules.kdeconnect = _: {
    programs.kdeconnect.enable = true;
    home-manager.sharedModules = [ self.homeModules.kdeconnect ];
  };

  flake.homeModules.kdeconnect = _: {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
