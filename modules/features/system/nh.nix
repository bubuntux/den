{ self, ... }:
let
  commonNh = lib: {
    enable = true;
    flake = lib.mkDefault self.lib.remoteFlake;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 10 --keep-since 14d";
    };
  };
in
{
  flake.modules = {
    nixos.nh =
      { lib, ... }:
      {
        key = "den:nixos.nh";
        programs.nh = commonNh lib;
        home-manager.sharedModules = [ self.modules.homeManager.nh ];
      };

    homeManager.nh =
      { lib, ... }:
      {
        key = "den:homeManager.nh";
        programs.nh = commonNh lib;
      };
  };
}
