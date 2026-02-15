# Sway modes configuration
# This file returns a function that takes pkgs and mod, then returns modes
# It's imported by default.nix, not as a flake-parts module
pkgs: mod: {
  resize = {
    "h" = "resize shrink width 10 px";
    "j" = "resize grow height 10 px";
    "k" = "resize shrink height 10 px";
    "l" = "resize grow width 10 px";
    "Left" = "resize shrink width 10 px";
    "Down" = "resize grow height 10 px";
    "Up" = "resize shrink height 10 px";
    "Right" = "resize grow width 10 px";
    "Return" = "mode default";
    "Escape" = "mode default";
  };

  # System mode (lock, exit, suspend, reboot, shutdown)
  "(l)ock, (e)xit, (s)uspend, (r)eboot, (Shift+s)hutdown" = {
    "l" = "exec swaylock -f, mode default";
    "s" = "exec systemctl suspend, mode default";
    "e" = "exec swaymsg exit, mode default";
    "r" = "exec systemctl reboot, mode default";
    "Shift+s" = "exec systemctl poweroff, mode default";
    "Return" = "mode default";
    "Escape" = "mode default";
  };

  # Screenshot mode
  "screenshot: (a)ctive, (s)creen, (o)utput, (r)egion, (w)indow" = {
    "a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot --notify save active, mode default";
    "s" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot --notify save screen, mode default";
    "o" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot --notify save output, mode default";
    "r" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot --notify save area, mode default";
    "w" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot --notify save window, mode default";
    "Return" = "mode default";
    "Escape" = "mode default";
  };

  # Passthrough mode (forward all keys to focused application)
  passthrough = {
    "${mod}+Pause" = "mode default";
  };
}
