{
  flake.homeModules.jujutsu =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.jj-starship ];

      programs.jujutsu = {
        enable = true;
        settings = {
          ui.default-command = "log";
          ui.editor = "hx"; # Helix is the repo's sole editor
          # Render diffs structurally with difftastic (already on PATH).
          ui.diff-formatter = [
            "difft"
            "--color=always"
            "$left"
            "$right"
          ];

          # Auto-track all bookmarks from the "origin" remote (git-like).
          remotes.origin.auto-track-bookmarks = "*";

          # Built-in aliases already provided by jj: st, b, ci, desc.
          aliases = {
            init = [
              "git"
              "init"
            ]; # colocated .git+.jj by default in jj 0.41
            clone = [
              "git"
              "clone"
            ]; # colocated by default
            push = [
              "git"
              "push"
            ];
            fetch = [
              "git"
              "fetch"
            ];
            pull = [
              "git"
              "fetch"
            ]; # jj has no merge-pull; fetch is the closest equivalent
            # Advance the nearest bookmark to the parent of the working copy.
            tug = [
              "bookmark"
              "move"
              "--from"
              "closest_bookmark(@-)"
              "--to"
              "@-"
            ];
          };

          revset-aliases."closest_bookmark(to)" = "heads(::to & bookmarks())";
        };
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
