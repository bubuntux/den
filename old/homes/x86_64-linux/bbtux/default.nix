{ pkgs, ... }:
{
  imports = [
    ./work
    #./steam.nix
  ]; # lib.snowfall.fs.get-default-nix-files-recursive ./.;

  # TODO: relocate
  home.packages = with pkgs; [
    clipman
    gammastep
    wdisplays

    gemini-cli-bin
    qbittorrent

    gimp3-with-plugins
    simple-scan

    spotify
    tidal-hifi
  ];

}
