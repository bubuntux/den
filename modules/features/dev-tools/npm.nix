{
  flake.modules.homeManager.npm =
    { config, ... }:
    {
      key = "den:homeManager.npm";
      home.sessionVariables = {
        npm_config_cache = "${config.xdg.cacheHome}/npm";
        NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
      };
    };
}
