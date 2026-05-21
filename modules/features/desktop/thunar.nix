{ self, ... }:
let
  mimeDefaults = {
    "inode/directory" = "thunar.desktop";
    "x-scheme-handler/file" = "thunar.desktop";
  };
in
{
  flake.nixosModules.thunar =
    { pkgs, ... }:
    {
      services.gvfs.enable = true; # Mount, trash, and other functionalities
      services.tumbler.enable = true; # Thumbnail support for images
      programs.thunar = {
        enable = true;
        plugins = with pkgs; [
          thunar-media-tags-plugin
          thunar-archive-plugin
          thunar-volman
        ];
      };
      xdg.mime.defaultApplications = mimeDefaults;
      home-manager.sharedModules = [ self.homeModules.thunar ];
    };

  flake.homeModules.thunar = _: {
    xdg.mimeApps.defaultApplications = mimeDefaults;
  };
}
