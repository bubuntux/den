{
  flake.modules.homeManager.git =
    { pkgs, ... }:
    {
      key = "den:homeManager.git";
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
            push.autoSetupRemote = true;
          };
          ignores = [
            # Nix & environment tooling
            "result"
            "result-*"
            ".direnv"
            ".devenv*"
            "devenv.local.nix"

            # Eclipse / JDT LS
            ".project"
            ".classpath"
            ".factorypath"
            ".settings/"

            # Editors & IDEs
            ".idea/"
            ".vscode/"
            "*.swp"
            "*.swo"
            "*~"

            # OS metadata
            ".DS_Store"
            "Thumbs.db"

            # AI & agent tooling
            ".claude/settings.local.json"
            ".claude/*.local.json"
            ".agents/scratch/"
            ".agents/*.local.*"
            "AGENTS.local.md"
            "GEMINI.local.md"
            ".gemini/"
            ".antigravity/"
          ];
        };

        gitui.enable = true;
      };
    };
}
