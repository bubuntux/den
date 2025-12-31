{ lib, pkgs, ... }:
with lib;
{

  imports = snowfall.fs.get-non-default-nix-files ./.;

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
    };
  };

  targets.genericLinux.enable = true;

  services = {
    blueman-applet.enable = true;
    network-manager-applet.enable = true;
  };

  home.packages = with pkgs; [
    discord

    kdePackages.dolphin
    kdePackages.okular

    loupe
    # proton-pass
    qalculate-gtk
    slack
    #spotify

    typst

    pwvucontrol
    wdisplays
  ];
}
