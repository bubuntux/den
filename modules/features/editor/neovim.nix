{
  flake.homeModules.neovim =
    { pkgs, ... }:
    {
      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
        withNodeJs = true;
        withPython3 = true;
        vimdiffAlias = true;
        defaultEditor = true;
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
