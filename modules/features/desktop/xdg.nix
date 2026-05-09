{
  flake.homeModules.xdg = _: {
    xdg = {
      enable = true;
      mimeApps.enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;
      };
    };
  };
}
