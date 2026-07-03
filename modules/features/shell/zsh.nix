{ self, ... }:
{
  # Interactive zsh configuration (Home Manager).
  flake.homeModules.zsh =
    { config, ... }:
    {
      programs.zsh = {
        enable = true;
        # Adopt the upcoming XDG default (dotfiles in ~/.config/zsh) instead of
        # the legacy home-dir location. Safe here: HM manages the config, so
        # there is nothing to migrate.
        dotDir = "${config.xdg.configHome}/zsh";
        enableCompletion = true;
        autosuggestion.enable = true; # fish-style inline history suggestions
        syntaxHighlighting.enable = true; # colorize commands as you type
        historySubstringSearch.enable = true; # prefix + up/down walks matches

        history = {
          size = 100000;
          save = 100000;
          ignoreDups = true;
          ignoreAllDups = true;
          share = true;
          expireDuplicatesFirst = true;
        };

        setOptions = [
          "AUTO_CD" # type a directory name to cd into it
          "AUTO_PUSHD" # cd maintains a directory stack (cd -<Tab>)
          "PUSHD_IGNORE_DUPS"
        ];
      };
    };

  # Register zsh as the login shell (NixOS). Wired into bundle-host so it
  # applies to hosts only — the work container imports bundle-base and keeps
  # bash (see modules/features/virtualisation/work-container.nix).
  flake.nixosModules.zsh =
    { pkgs, ... }:
    {
      programs.zsh.enable = true;
      users.defaultUserShell = pkgs.zsh;

      home-manager.sharedModules = [ self.homeModules.zsh ];
    };
}
