{
  flake.nixosModules.ntpdrs = _: {
    # Disable systemd-timesyncd in favor of ntpd-rs
    services.timesyncd.enable = false;
    services.ntpd-rs.enable = true;
  };
}
