{
  flake.homeModules.jujutsu = _: {
    programs.jujutsu = {
      enable = true;
      settings.ui.default-command = "log";
    };
  };
}
