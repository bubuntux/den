{
  flake.modules.homeManager.go =
    { config, ... }:
    {
      key = "den:homeManager.go";
      home.sessionVariables.GOPATH = "${config.xdg.dataHome}/go";
      home.sessionPath = [ "$GOPATH/bin" ];
    };
}
