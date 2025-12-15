{ pkgs, ... }:
{
  per.fonts.nixos = {
    fonts = {
      fontDir.enable = true;
      packages = with pkgs.nerd-fonts; [
        fira-code
        hack
        jetbrains-mono
        sauce-code-pro
        dejavu-sans-mono
      ];
    };
  };
}
