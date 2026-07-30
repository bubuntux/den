{
  flake.modules.homeManager.go = _: {
    home.sessionVariables.GOPATH = "$HOME/.go";
    home.sessionPath = [ "$GOPATH/bin" ];
  };
}
