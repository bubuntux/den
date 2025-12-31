{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    font-awesome
    roboto
    source-sans
    source-sans-pro
    nerd-fonts.roboto-mono
    nerd-fonts.fira-code
    nerd-fonts.meslo-lg
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    nerd-fonts.sauce-code-pro
    nerd-fonts.dejavu-sans-mono
  ];
}
