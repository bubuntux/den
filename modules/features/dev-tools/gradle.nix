{
  flake.modules.homeManager.gradle =
    { config, ... }:
    {
      key = "den:homeManager.gradle";
      home.sessionVariables = {
        GRADLE_USER_HOME = "${config.xdg.dataHome}/gradle";
      };
    };
}
