{ self, ... }:
{
  flake.nixosModules.wifi-work =
    { config, ... }:
    {
      imports = [ self.nixosModules.sops ];

      sops.secrets.wifi_work_ssid = {
        sopsFile = "${self}/secrets/work.yaml";
      };

      sops.secrets.wifi_work_psk = {
        sopsFile = "${self}/secrets/work.yaml";
      };

      sops.templates."wifi-work-env".content = ''
        wifi_work_ssid=${config.sops.placeholder.wifi_work_ssid}
        wifi_work_psk=${config.sops.placeholder.wifi_work_psk}
      '';

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [
          config.sops.templates."wifi-work-env".path
        ];

        profiles.work-wifi = {
          connection = {
            id = "$wifi_work_ssid";
            type = "wifi";
            autoconnect-priority = "5";
          };
          wifi = {
            ssid = "$wifi_work_ssid";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$wifi_work_psk";
          };
        };
      };
    };
}
