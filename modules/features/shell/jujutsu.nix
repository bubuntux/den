{
  flake.homeModules.jujutsu =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.jj-starship ];

      programs.jujutsu = {
        enable = true;
        settings.ui.default-command = "log";
      };

      # Unified Starship prompt: jj-starship renders jj status inside jj repos
      # and falls back to git status in plain git repos. Disable the built-in
      # git modules so they don't double up inside colocated (.git + .jj) repos.
      programs.starship.settings = {
        git_branch.disabled = true;
        git_commit.disabled = true;
        git_state.disabled = true;
        git_status.disabled = true;

        custom.jj = {
          when = "jj-starship detect";
          shell = [ "jj-starship" ];
          format = "$output ";
        };
      };
    };
}
