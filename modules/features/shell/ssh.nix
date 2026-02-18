{
  flake.homeModules.ssh = _: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
    };
  };
}
