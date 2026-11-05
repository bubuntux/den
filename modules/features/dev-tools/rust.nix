{
  flake.modules.homeManager.rust =
    { config, ... }:
    {
      key = "den:homeManager.rust";
      home.sessionVariables = {
        CARGO_HOME = "${config.xdg.dataHome}/cargo";
        RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
      };
      home.sessionPath = [ "$CARGO_HOME/bin" ];
    };
}
