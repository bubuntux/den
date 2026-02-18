{ self, ... }:
{
  flake.nixosModules.firefox =
    { pkgs, ... }:
    {
      programs.firefox = {
        enable = true;
        package = pkgs.firefox;
        preferences = {
          "font.name-list.sans-serif.x-western" = "Roboto, Noto Sans, Symbols Nerd Font";
          "font.name-list.serif.x-western" = "Noto Serif, Symbols Nerd Font";
          "font.name-list.monospace.x-western" = "JetBrainsMono Nerd Font, Symbols Nerd Font";
          "font.name-list.sans-serif.x-unicode" = "Roboto, Noto Sans, Symbols Nerd Font";
          "font.name-list.serif.x-unicode" = "Noto Serif, Symbols Nerd Font";
          "font.name-list.monospace.x-unicode" = "JetBrainsMono Nerd Font, Symbols Nerd Font";
          "gfx.font_rendering.fontconfig.max_generic_substitutions" = 127;
        };
      };
      home-manager.sharedModules = [ self.homeModules.firefox ];
    };

  flake.homeModules.firefox = {
    xdg.mimeApps.defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
