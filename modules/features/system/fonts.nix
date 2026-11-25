let
  fontPackages =
    pkgs: with pkgs; [
      liberation_ttf
      noto-fonts
      noto-fonts-color-emoji
      roboto
      nerd-fonts.symbols-only
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      nerd-fonts.sauce-code-pro
      nerd-fonts.dejavu-sans-mono
    ];
in
{
  flake.modules = {
    nixos.fonts =
      { pkgs, ... }:
      {
        key = "den:nixos.fonts";
        fonts = {
          fontDir.enable = true;
          packages = fontPackages pkgs;
          fontconfig.subpixel.rgba = "rgb";
          fontconfig.defaultFonts = {
            monospace = [
              "JetBrainsMono Nerd Font"
              "FiraCode Nerd Font"
              "DejaVuSansM Nerd Font"
            ];
            sansSerif = [
              "Roboto"
              "Noto Sans"
            ];
            serif = [
              "Noto Serif"
            ];
          };
        };
      };

    homeManager.fonts =
      { pkgs, ... }:
      {
        key = "den:homeManager.fonts";
        fonts.fontconfig.enable = true;
        home.packages = fontPackages pkgs;
      };
  };
}
