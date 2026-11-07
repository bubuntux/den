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
      };

    homeManager.nh =
      {
        lib,
        osConfig ? null,
        ...
      }:
      {
        key = "den:homeManager.nh";
        # Yield to NixOS when `nixos.nh` is active so HM doesn't clobber NH_FLAKE or run a second gc timer.
        programs.nh = lib.mkIf (!(osConfig.programs.nh.enable or false)) (commonNh lib);
      };
  };
}
