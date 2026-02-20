{
  flake.homeModules.git =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lazygit ];

      programs = {
        git = {
          enable = true;
          settings = {
            alias = {
              p = "pull --ff-only";
              ff = "merge --ff-only";
              graph = "log --decorate --oneline --graph";
            };
            init.defaultBranch = "main";
          };
          ignores = [
            ".direnv"
            ".claude/settings.local.json"
            "result"
          ];
        };

        gitui.enable = true;
      };
    };
}
