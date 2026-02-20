{
  flake.homeModules.neovim =
    { config, pkgs, ... }:
    {
      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
        withNodeJs = true;
        withPython3 = true;
        vimdiffAlias = true;
        defaultEditor = !config.programs.helix.defaultEditor;
        extraPackages = with pkgs; [
          # Astronvim
          ripgrep
          lazygit
          gdu
          bottom

          # wayland
          wl-clipboard
        ];
      };
    };
}
