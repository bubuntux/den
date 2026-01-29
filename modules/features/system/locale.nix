{
  flake.nixosModules.locale = {
    time.timeZone = "America/Chicago";
    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "es_MX.UTF-8/UTF-8"
        "es_MX/ISO-8859-1"
      ];
    };
  };
}
