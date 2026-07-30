{
  flake.modules.nixos.ntpdrs = {
    key = "den:nixos.ntpdrs";
    # Disable systemd-timesyncd in favor of ntpd-rs
    services.timesyncd.enable = false;
    services.ntpd-rs.enable = true;
  };
}
