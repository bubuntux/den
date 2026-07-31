# Sway startup commands.
# This file returns a function that takes pkgs, then returns the list sway's
# `config.startup` expects. It's imported by default.nix, not as a flake-parts
# module.
#
# These three daemons are not Sway-specific in themselves -- any bare session
# wants a clipboard manager and a PolicyKit agent -- but a compositor `exec`
# entry is, so they stay here rather than in session/wayland.nix. A second
# session repeats three lines in its own syntax; turning them into user units
# bound to den-session.target would share them, at the cost of changing how a
# working session starts them.
pkgs: [
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
]
