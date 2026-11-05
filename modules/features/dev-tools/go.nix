{
  flake.modules.homeManager.go = {
    key = "den:homeManager.go";
    home.sessionVariables.GOPATH = "$HOME/.local/share/go";
    home.sessionPath = [ "$GOPATH/bin" ];
  };
}
