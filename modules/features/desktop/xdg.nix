{
  flake.modules.homeManager.xdg = {
    key = "den:homeManager.xdg";
    # GTK/glib apps and `xdg-mime` rewrite mimeapps.list in place, replacing
    # Home Manager's symlink with a regular file. HM then backs that file up on
    # the next switch and aborts as soon as a `.bkp` from an earlier switch is
    # already there. Overwrite instead of backing up — the generated file is the
    # source of truth for these associations.
    xdg.configFile."mimeapps.list".force = true;
    xdg.dataFile."applications/mimeapps.list".force = true;

    xdg = {
      enable = true;
      mimeApps.enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = false;
      };
    };
  };
}
