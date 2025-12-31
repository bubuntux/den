{
  lib,
  osConfig ? { },
  ...
}:
with lib;
{
  imports = snowfall.fs.get-non-default-nix-files-recursive ./.;
  programs.home-manager.enable = true;
  home.stateVersion = lib.mkDefault (osConfig.system.stateVersion or "24.11");

  services.home-manager.autoExpire = {
    enable = true;
    frequency = "weekly";
    timestamp = "-30 days";
    store = {
      cleanup = true;
      options = "--delete-older-than 30d";
    };
  };
}
