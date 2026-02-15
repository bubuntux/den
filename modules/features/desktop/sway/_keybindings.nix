# Sway keybindings configuration
# This file returns a function that takes pkgs and mod, then returns keybindings
# It's imported by default.nix, not as a flake-parts module
pkgs: mod: {
  # Terminal
  "${mod}+Return" = "exec foot";

  # Kill window
  "${mod}+Shift+q" = "kill";

  # Launcher
  "${mod}+d" = "exec rofi -terminal foot -show combi -combi-modes drun#run -modes combi";

  # Reload
  "${mod}+Shift+c" = "reload";

  # Focus (vim keys)
  "${mod}+h" = "focus left";
  "${mod}+j" = "focus down";
  "${mod}+k" = "focus up";
  "${mod}+l" = "focus right";

  # Focus (arrow keys)
  "${mod}+Left" = "focus left";
  "${mod}+Down" = "focus down";
  "${mod}+Up" = "focus up";
  "${mod}+Right" = "focus right";

  # Move (vim keys)
  "${mod}+Shift+h" = "move left";
  "${mod}+Shift+j" = "move down";
  "${mod}+Shift+k" = "move up";
  "${mod}+Shift+l" = "move right";

  # Move (arrow keys)
  "${mod}+Shift+Left" = "move left";
  "${mod}+Shift+Down" = "move down";
  "${mod}+Shift+Up" = "move up";
  "${mod}+Shift+Right" = "move right";

  # Workspaces
  "${mod}+1" = "workspace number 1";
  "${mod}+2" = "workspace number 2";
  "${mod}+3" = "workspace number 3";
  "${mod}+4" = "workspace number 4";
  "${mod}+5" = "workspace number 5";
  "${mod}+6" = "workspace number 6";
  "${mod}+7" = "workspace number 7";
  "${mod}+8" = "workspace number 8";
  "${mod}+9" = "workspace number 9";
  "${mod}+0" = "workspace number 10";

  # Move to workspace
  "${mod}+Shift+1" = "move container to workspace number 1";
  "${mod}+Shift+2" = "move container to workspace number 2";
  "${mod}+Shift+3" = "move container to workspace number 3";
  "${mod}+Shift+4" = "move container to workspace number 4";
  "${mod}+Shift+5" = "move container to workspace number 5";
  "${mod}+Shift+6" = "move container to workspace number 6";
  "${mod}+Shift+7" = "move container to workspace number 7";
  "${mod}+Shift+8" = "move container to workspace number 8";
  "${mod}+Shift+9" = "move container to workspace number 9";
  "${mod}+Shift+0" = "move container to workspace number 10";

  # Layout
  "${mod}+b" = "splith";
  "${mod}+v" = "splitv";
  "${mod}+s" = "layout stacking";
  "${mod}+w" = "layout tabbed";
  "${mod}+e" = "layout toggle split";
  "${mod}+f" = "fullscreen";
  "${mod}+Shift+space" = "floating toggle";
  "${mod}+space" = "focus mode_toggle";
  "${mod}+a" = "focus parent";

  # Scratchpad
  "${mod}+Shift+minus" = "move scratchpad";
  "${mod}+minus" = "scratchpad show";

  # Modes
  "${mod}+r" = "mode resize";
  "${mod}+Shift+e" = ''mode "(l)ock, (e)xit, (s)uspend, (r)eboot, (Shift+s)hutdown"'';
  "${mod}+Shift+s" = ''mode "screenshot: (a)ctive, (s)creen, (o)utput, (r)egion, (w)indow"'';
  "${mod}+Pause" = "mode passthrough";

  # Window switcher and sticky
  "${mod}+Tab" = "exec rofi -show window";
  "${mod}+Ctrl+s" = "sticky toggle";

  # Clipboard history
  "Ctrl+Alt+h" = "exec clipman pick -t rofi --max-items=1000";

  # Media keys
  "--locked XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
  "--locked XF86AudioStop" = "exec ${pkgs.playerctl}/bin/playerctl stop";
  "XF86AudioForward" = "exec ${pkgs.playerctl}/bin/playerctl position +10";
  "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
  "XF86AudioPause" = "exec ${pkgs.playerctl}/bin/playerctl pause";
  "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
  "XF86AudioRewind" = "exec ${pkgs.playerctl}/bin/playerctl position -10";

  # Volume keys
  "--locked XF86AudioRaiseVolume" =
    "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
  "--locked XF86AudioLowerVolume" =
    "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
  "--locked XF86AudioMute" = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
  "--locked XF86AudioMicMute" =
    "exec ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";

  # Brightness keys
  "XF86MonBrightnessDown" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
  "XF86MonBrightnessUp" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set +5%";
}
