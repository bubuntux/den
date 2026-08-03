{ self, ... }:
{
  # The other terminal behind den.desktop.terminal, and the default. GPU
  # rendering is not why -- see CLAUDE.md, "Choosing a terminal".
  flake.modules.homeManager.ghostty = {
    key = "den:homeManager.ghostty";
    imports = [ self.modules.homeManager.session-options ];

    den.session.terminal = "ghostty";

    programs.ghostty = {
      enable = true;

      settings = {
        # Upstream's default list with the two ssh features flipped on; setting
        # the key replaces it wholesale, so the rest is repeated verbatim.
        shell-integration-features = "cursor,no-sudo,title,ssh-env,ssh-terminfo,path";

        theme = "One Dark Two";

        confirm-close-surface = false;
        resize-overlay = "never";

        font-family = "Hack Nerd Font Mono";
        font-size = 12;
        background-opacity = 0.9;
        mouse-hide-while-typing = true;

        # Not "none": this file is home-wide and GNOME would lose its titlebar
        # with it. See CLAUDE.md, "Choosing a terminal".
        window-decoration = "server";
      };
    };
  };
}
