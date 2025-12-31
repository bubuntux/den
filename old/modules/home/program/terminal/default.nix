{
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      # devenv

      ranger

      # process
      bottom
      htop

      # request/parsers
      httpie
      jq
      yq-go

      # archives
      p7zip
      rar
      unzip
      xz
      zip
    ];
    # shellAliases = {
    #   cat = "bat --paging=never";
    # };
  };

  programs = {
    bash.enable = true;
    # bat.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    eza.enable = true;

    starship.enable = true;
  };
}
