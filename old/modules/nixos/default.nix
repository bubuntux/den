{
  host,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
{
  imports = snowfall.fs.get-non-default-nix-files ./.;

  networking = {
    hostName = "${host}";
    # useDHCP = true;
    # domain = "home.arpa";
  };

  time.timeZone = "America/Chicago";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "es_MX.UTF-8/UTF-8"
      "es_MX/ISO-8859-1"
    ];
  };

  networking.timeServers = options.networking.timeServers.default ++ [
    "time.cloudflare.com"
    "time.google.com"
    "ohio.time.system76.com"
    "oregon.time.system76.com"
    "virginia.time.system76.com"
  ];
  services.chrony = {
    enable = true;
    enableNTS = true;
  };

  services = {
    # TODO MOVE?
    flatpak.enable = true;
  };

  # services.automatic-timezoned.enable = true;
  # services.localtimed.enable = true;
  services.geoclue2.enable = true;
  location = {
    provider = "geoclue2";
    #   latitude = 30.2;
    #   longitude = -97.7;
  };

  fonts = {
    fontDir.enable = true;
    # bundle so it gets reused for home?
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      nerd-fonts.sauce-code-pro
      nerd-fonts.dejavu-sans-mono
    ];
  };

}
