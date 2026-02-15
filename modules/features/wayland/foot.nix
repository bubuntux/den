{
  flake.homeModules.foot = {
    programs.foot = {
      enable = true;
      settings = {
        main = {
          term = "xterm-256color";
          font = "Hack Nerd Font Mono:size=12";
          dpi-aware = "yes";
        };
        colors = {
          alpha = 0.90;
        };
        mouse = {
          hide-when-typing = "yes";
        };
      };
    };
  };
}
