{ self, ... }:
{
  flake.nixosModules.firefox =
    { pkgs, ... }:
    {
      programs.firefox = {
        enable = true;
        package = pkgs.firefox;
        preferences = {
          "font.name-list.sans-serif.x-western" = "Roboto, Noto Sans, FiraCode Nerd Font Propo";
          "font.name-list.serif.x-western" = "Noto Serif, FiraCode Nerd Font Propo";
          "font.name-list.monospace.x-western" = "JetBrainsMono Nerd Font, FiraCode Nerd Font";
          "font.name-list.sans-serif.x-unicode" = "Roboto, Noto Sans, FiraCode Nerd Font Propo";
          "font.name-list.serif.x-unicode" = "Noto Serif, FiraCode Nerd Font Propo";
          "font.name-list.monospace.x-unicode" = "JetBrainsMono Nerd Font, FiraCode Nerd Font";
          "gfx.font_rendering.fontconfig.max_generic_substitutions" = 127;
        };
      };
      home-manager.sharedModules = [ self.homeModules.firefox ];
    };

  flake.homeModules.firefox = _: {
    xdg.mimeApps.defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
