{ pkgs, ... }:
{
  # programs.lazygit.enable = true;
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

      # Java
      # jdk
      # gradle
      # maven
      # vimPlugins.nvim-java
      # vimPlugins.nvim-java-core

      # Rust
      pkg-config
      openssl
      rustup
      libgcc
      gcc

      # Nix
      nixd
      deadnix
      statix
    ];
  };

}
