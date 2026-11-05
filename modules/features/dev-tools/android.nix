{
  flake.modules.homeManager.android = {
    key = "den:homeManager.android";
    home.sessionVariables = {
      ANDROID_HOME = "$HOME/.local/share/android/sdk";
      ANDROID_SDK_ROOT = "$HOME/.local/share/android/sdk";
    };
    home.sessionPath = [
      "$ANDROID_HOME/cmdline-tools/latest/bin"
      "$ANDROID_HOME/platform-tools"
    ];
  };
}
