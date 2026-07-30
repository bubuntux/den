{
  flake.modules.homeManager.devenv =
    { pkgs, ... }:
    {
      key = "den:homeManager.devenv";
      home.packages = [ pkgs.devenv ];
    };
}
