# Run automatic updates. Replaces system.autoUpgrade.
{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
{
  # Assert that system.autoUpgrade is not also enabled
  # assertions = [
  #   {
  #     assertion = !config.system.autoUpgrade.enable;
  #     message = "The system.autoUpgrade option conflicts with this module.";
  #   }
  # ];

  system.autoUpgrade = {
    # enable = true;
    dates = "daily";
    operation = "boot";
    flake = "/etc/nixos/";
    flags = [
      "--recreate-lock-file"
      # "--update-input"
      # "nixpkgs"
      # "--update-input"
      # "hardware"
      # "--update-input"
      # "home-manager"
      # "--update-input"
      # "snowfall-lib"
      "--commit-lock-file"
      "-L" # print build logs
    ];
  };

  # systemd = {
  #   services = {
  #     "nixflake-upgrade" = {
  #       serviceConfig = {
  #         Type = "oneshot";
  #         User = "bbtux";
  #       };
  #       before = ["nixos-upgrade.service"];
  #       path = with pkgs; [openssh openssl git nix];
  #       unitConfig.RequiresMountsFor = "/etc/nixos/";
  #       script = "
  #         cd /etc/nixos/
  #         git pull
  #         nix flake update --commit-lock-file
  #         git push
  #       ";
  #     };
  #     # "nixos-upgrade" = {
  #     #   serviceConfig = {
  #     #     Type = "oneshot";
  #     #     User = "root";
  #     #   };
  #     #   path = with pkgs; [openssh openssl git nix nixos-rebuild];
  #     #   unitConfig.RequiresMountsFor = "/etc/nixos/";
  #     #   script = "
  #     #     cd /etc/nixos/
  #     #     nixos-rebuild boot
  #     #   ";
  #     # };
  #   };
  #   # timers."nixos-upgrade" = {
  #   #   wants = ["network-online.target"];
  #   #   after = ["network-online.target"];
  #   #   wantedBy = ["timers.target"];
  #   #   timerConfig = {
  #   #     Persistent = true;
  #   #     OnCalendar = "daily";
  #   #     RandomizedDelaySec = "30m";
  #   #     Unit = "nixos-upgrade.service";
  #   #   };
  #   # };
  # };
}
