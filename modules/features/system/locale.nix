{
  flake.nixosModules.locale =
    { lib, ... }:
    {
      time.timeZone = lib.mkDefault null;
      services.automatic-timezoned.enable = true;
      services.geoclue2.enable = true;
      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocaleSettings = {
          LC_ADDRESS = "en_US.UTF-8";
          LC_IDENTIFICATION = "en_US.UTF-8";
          LC_MEASUREMENT = "en_US.UTF-8";
          LC_MONETARY = "en_US.UTF-8";
          LC_NAME = "en_US.UTF-8";
          LC_NUMERIC = "en_US.UTF-8";
          LC_PAPER = "en_US.UTF-8";
          LC_TELEPHONE = "en_US.UTF-8";
          LC_TIME = "en_US.UTF-8";
        };
        supportedLocales = [
          "en_US.UTF-8/UTF-8"
          "es_MX.UTF-8/UTF-8"
          "es_MX/ISO-8859-1"
        ];
      };
    };
}
