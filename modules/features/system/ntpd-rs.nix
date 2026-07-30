{
  flake.modules.nixos.ntpd-rs = {
    key = "den:nixos.ntpd-rs";
    # Disable systemd-timesyncd in favor of ntpd-rs
    services.timesyncd.enable = false;
    services.ntpd-rs.enable = true;
  };
}
