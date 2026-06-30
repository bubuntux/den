{
  flake.homeModules.difftastic = _: {
    programs.difftastic = {
      enable = true;

      # Wire difftastic into git: `diff.external` makes `git diff`/`git show`/
      # `git log -p` render structurally, and `diffToolMode` also configures
      # `git difftool`. Use `git diff --no-ext-diff` for plain unified output.
      git = {
        enable = true;
        diffToolMode = true;
      };
    };
  };
}
