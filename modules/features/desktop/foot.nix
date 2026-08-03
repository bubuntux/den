{ self, ... }:
{
  # One of the terminals behind den.desktop.terminal; the other is ghostty.
  # See CLAUDE.md, "Choosing a terminal".
  flake.modules.homeManager.foot = {
    key = "den:homeManager.foot";
    imports = [ self.modules.homeManager.session-options ];

    den.session.terminal = "footclient";

    programs.foot = {
      enable = true;

      # systemdTarget defaults to wayland.systemd.target, which session-wayland
      # already points at den-session.target.
      server.enable = true;

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
