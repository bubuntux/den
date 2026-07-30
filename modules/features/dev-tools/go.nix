{
  flake.modules.homeManager.go = {
    key = "den:homeManager.go";
    home.sessionVariables.GOPATH = "$HOME/.go";
    home.sessionPath = [ "$GOPATH/bin" ];
  };
}
