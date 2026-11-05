{
  flake.modules.homeManager.android =
    { config, ... }:
    {
      key = "den:homeManager.android";
      home.sessionVariables = {
        ANDROID_HOME = "${config.xdg.dataHome}/android/sdk";
        ANDROID_SDK_ROOT = "${config.xdg.dataHome}/android/sdk";
      };
      home.sessionPath = [
        "$ANDROID_HOME/cmdline-tools/latest/bin"
        "$ANDROID_HOME/platform-tools"
      ];
    };
}
