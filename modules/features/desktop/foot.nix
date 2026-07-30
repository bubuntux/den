{
  flake.modules.homeManager.foot = {
    key = "den:homeManager.foot";
    programs.foot = {
      enable = true;
      settings = {
        main = {
          term = "xterm-256color";
          font = "Hack Nerd Font Mono:size=12";
          dpi-aware = "yes";
        };
        colors-dark = {
          alpha = 0.90;
        };
        mouse = {
          hide-when-typing = "yes";
        };
      };
    };
  };
}
