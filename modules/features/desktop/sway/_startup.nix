# Sway startup commands and services configuration
# This file returns a function that takes pkgs, then returns startup config
# It's imported by default.nix, not as a flake-parts module
pkgs: {
  # Startup commands for sway
  commands = [
    # Clipboard manager
    {
      command = "${pkgs.wl-clipboard}/bin/wl-paste -t text --no-newline --watch ${pkgs.clipman}/bin/clipman store --no-persist --max-items=1000";
    }
    # PolicyKit agent
    {
      command = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
    }
    # XDG user dirs
    {
      command = "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update";
    }
  ];

  # Swayidle configuration
  swayidle = {
    enable = true;
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        event = "lock";
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
    ];
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        timeout = 360;
        command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
    ];
  };

  # Mako notification daemon
  mako = {
    enable = true;
    settings.default-timeout = 5000;
  };

  # Rofi launcher
  rofi = {
    enable = true;
    theme = "Arc-Dark";
    package = pkgs.rofi-wayland;
  };
}
