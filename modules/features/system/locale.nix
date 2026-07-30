{
  flake.modules.nixos.locale =
    {
      config,
      lib,
      options,
      ...
    }:
    {
      key = "den:nixos.locale";
      time.timeZone = lib.mkDefault null;
      services.automatic-timezoned.enable = true;

      # geoclue answers no GetClient call until an agent is registered for the
      # asking uid -- the request just sits in its clients_waiting_agent queue
      # (gclue-service-manager.c) -- and it only accepts an agent whose desktop
      # id is whitelisted. nixpkgs ties "geoclue-demo-agent" to enableDemoAgent,
      # which the GNOME module turns off because gnome-shell is its own agent.
      # That also disowns automatic-timezoned, which runs the demo agent itself,
      # and any non-GNOME session. So keep the id whitelisted here and let each
      # session bring the agent that suits it: gnome-shell under GNOME, an
      # explicit user service under Sway (features/desktop/session/sway/default.nix).
      services.geoclue2 = {
        enable = true;
        whitelistedAgents = options.services.geoclue2.whitelistedAgents.default ++ [
          "geoclue-demo-agent"
        ];
        enableDemoAgent = lib.mkForce false;
      };

      # nixpkgs leaves Restart unset on this unit, so a single unlucky start --
      # geoclue not yet reachable, or no network for the wifi source -- leaves
      # the machine on a stale timezone until someone restarts it by hand.
      # Guarded on the service's own enable flag: appa turns it off, and an
      # unconditional systemd.services entry would leave a stray ExecStart-less
      # unit behind there.
      systemd.services.automatic-timezoned = lib.mkIf config.services.automatic-timezoned.enable {
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 5;
          RestartSteps = 5;
          RestartMaxDelaySec = 300;
        };
      };
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
