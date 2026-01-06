{ pkgs, ... }:
{

  programs.vscode.enable = true;

  home = {
    sessionVariables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      GOPATH = "$HOME/.go";
      # NIX_LD_LIBRARY_PATH = nixLdLibraryPath;
      # NIX_LD = nixLdPath;
    };
    sessionPath = [
      "$HOME/.cargo/bin"
      "$HOME/.go/bin"
    ];
    packages = with pkgs; [
      pkg-config
      openssl

      # devenv

      podman
      podman-compose

      # fenix setup?  https://github.com/nix-community/fenix
      libgcc
      gcc
      rustup
    ];
  };
}
