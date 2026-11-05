{
  flake.modules.homeManager.rust = {
    key = "den:homeManager.rust";
    home.sessionVariables = {
      CARGO_HOME = "$HOME/.local/share/cargo";
      RUSTUP_HOME = "$HOME/.local/share/rustup";
    };
    home.sessionPath = [ "$CARGO_HOME/bin" ];
  };
}
