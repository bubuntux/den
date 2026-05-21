{ self, ... }:
let
  mimeDefaults = builtins.listToAttrs (
    map
      (m: {
        name = m;
        value = "org.gnome.Loupe.desktop";
      })
      [
        "image/jpeg"
        "image/png"
        "image/gif"
        "image/webp"
        "image/tiff"
        "image/bmp"
        "image/svg+xml"
        "image/svg+xml-compressed"
        "image/vnd.microsoft.icon"
        "image/x-icon"
        "image/heic"
        "image/heif"
        "image/avif"
        "image/jxl"
        "image/x-portable-bitmap"
        "image/x-portable-graymap"
        "image/x-portable-pixmap"
        "image/x-portable-anymap"
        "image/x-exr"
        "image/qoi"
        "image/x-qoi"
      ]
  );
in
{
  flake.nixosModules.loupe =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.loupe ];
      xdg.mime.defaultApplications = mimeDefaults;
      home-manager.sharedModules = [ self.homeModules.loupe ];
    };

  flake.homeModules.loupe = _: {
    xdg.mimeApps.defaultApplications = mimeDefaults;
  };
}
