{
  flake.homeModules.git =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lazygit ];

      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              name = "Julio Gutierrez";
              email = "413330+bubuntux@users.noreply.github.com";
            };
            alias = {
              p = "pull --ff-only";
              ff = "merge --ff-only";
              graph = "log --decorate --oneline --graph";
            };
            init.defaultBranch = "main";
          };
          ignores = [
            ".direnv"
            "result"
          ];
        };

        gitui.enable = true;
      };
    };
}
