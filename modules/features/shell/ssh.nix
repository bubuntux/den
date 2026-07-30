{
  flake.modules.homeManager.ssh = {
    key = "den:homeManager.ssh";
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
    };
  };
}
