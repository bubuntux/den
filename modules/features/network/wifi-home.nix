{ self, ... }:
{
  flake.nixosModules.wifi-home =
    { config, ... }:
    {
      imports = [ self.nixosModules.sops ];

      sops.secrets.wifi_home_ssid = {
        sopsFile = "${self}/secrets/common.yaml";
      };

      sops.secrets.wifi_home_psk = {
        sopsFile = "${self}/secrets/common.yaml";
      };

      sops.secrets.wifi_home_guest_ssid = {
        sopsFile = "${self}/secrets/common.yaml";
      };

      sops.secrets.wifi_home_guest_psk = {
        sopsFile = "${self}/secrets/common.yaml";
      };

      sops.templates."wifi-home-env".content = ''
        wifi_home_ssid=${config.sops.placeholder.wifi_home_ssid}
        wifi_home_psk=${config.sops.placeholder.wifi_home_psk}
        wifi_home_guest_ssid=${config.sops.placeholder.wifi_home_guest_ssid}
        wifi_home_guest_psk=${config.sops.placeholder.wifi_home_guest_psk}
      '';

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [
          config.sops.templates."wifi-home-env".path
        ];

        profiles.home-wifi = {
          connection = {
            id = "$wifi_home_ssid";
            type = "wifi";
            autoconnect-priority = "10";
          };
          wifi = {
            ssid = "$wifi_home_ssid";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$wifi_home_psk";
          };
        };

        profiles.home-wifi-guest = {
          connection = {
            id = "$wifi_home_guest_ssid";
            type = "wifi";
            autoconnect-priority = "1";
          };
          wifi = {
            ssid = "$wifi_home_guest_ssid";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$wifi_home_guest_psk";
          };
        };
      };
    };
}
