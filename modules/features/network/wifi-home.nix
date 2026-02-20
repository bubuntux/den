{ self, ... }:
{
  flake.nixosModules.wifi-home =
    { config, ... }:
    {
      imports = [ self.nixosModules.sops ];

      sops.secrets.wifi_home_psk = {
        sopsFile = "${self}/secrets/common.yaml";
      };

      sops.secrets.wifi_home_guest_psk = {
        sopsFile = "${self}/secrets/common.yaml";
      };

      networking.networkmanager.ensureProfiles = {
        profiles.home-wifi = {
          connection = {
            id = "GC";
            type = "wifi";
            autoconnect-priority = "10";
          };
          wifi = {
            ssid = "GC";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk-flags = "0";
          };
        };

        profiles.home-wifi-guest = {
          connection = {
            id = "GC_Guest";
            type = "wifi";
            autoconnect-priority = "1";
          };
          wifi = {
            ssid = "GC_Guest";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk-flags = "0";
          };
        };

        secrets.entries = [
          {
            matchId = "GC";
            matchSetting = "wifi-security";
            key = "psk";
            file = config.sops.secrets.wifi_home_psk.path;
          }
          {
            matchId = "GC_Guest";
            matchSetting = "wifi-security";
            key = "psk";
            file = config.sops.secrets.wifi_home_guest_psk.path;
          }
        ];
      };
    };
}
