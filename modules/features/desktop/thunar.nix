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
    };
}
