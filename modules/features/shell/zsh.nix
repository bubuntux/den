{ self, ... }:
{
  # Interactive zsh configuration (Home Manager).
  flake.homeModules.zsh =
    { config, lib, ... }:
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

      # Put the NixOS per-user and system completion dirs on fpath before
      # compinit runs (HM runs compinit at order 570). HM's own fpath loop
      # only covers $NIX_PROFILES, which can go stale in a long-lived session:
      # `nixos-rebuild switch` updates /etc/set-environment, but the running
      # session keeps its old $NIX_PROFILES (frozen by __NIXOS_SET_ENVIRONMENT_DONE),
      # so per-user completions like jj's _jj never reach fpath until re-login.
      # Sourcing the paths directly makes completions work in new shells without
      # a reboot and is robust against that staleness. (Missing dirs are ignored.)
      programs.zsh.initContent = lib.mkOrder 550 ''
        fpath=(
          /etc/profiles/per-user/$USER/share/zsh/site-functions
          /run/current-system/sw/share/zsh/site-functions
          $fpath
        )
      '';
    };

  # Register zsh as the login shell (NixOS). Wired into bundle-host so it
  # applies to hosts only — the work container imports bundle-base and keeps
  # bash (see modules/features/virtualisation/work-container.nix).
  flake.nixosModules.zsh =
    { pkgs, ... }:
    {
      programs.zsh.enable = true;
      users.defaultUserShell = pkgs.zsh;

      # Wrap in an attrset with an explicit key so Home Manager deduplicates
      # this sharedModule when bundle-host is reached through multiple NixOS
      # import paths (e.g. profile-laptop and bundle-desktop). Without it the
      # module applies twice, doubling additive options like initContent.
      home-manager.sharedModules = [
        {
          key = "homeModules.zsh";
          imports = [ self.homeModules.zsh ];
        }
      ];
    };
}
