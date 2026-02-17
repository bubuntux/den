# Sway window rules configuration
[
  # Browser marks
  {
    criteria.class = "Chromium-browser";
    command = "mark Browser";
  }
  {
    criteria.class = "Brave-browser";
    command = "mark Browser";
  }
  {
    criteria.class = "firefox";
    command = "mark Browser";
  }
  {
    criteria.class = "LibreWolf";
    command = "mark Browser";
  }
  {
    criteria.app_id = "Chromium-browser";
    command = "mark Browser";
  }
  {
    criteria.app_id = "brave-browser";
    command = "mark Browser";
  }
  {
    criteria.app_id = "firefox";
    command = "mark Browser";
  }
  {
    criteria.app_id = "LibreWolf";
    command = "mark Browser";
  }
  {
    criteria.con_mark = "Browser";
    command = "inhibit_idle fullscreen";
  }

  # Firefox sharing indicator
  {
    criteria = {
      app_id = "firefox";
      title = "Firefox — Sharing Indicator";
    };
    command = "floating enable";
  }

  # Picture-in-Picture
  {
    criteria = {
      con_mark = "Browser";
      title = "Picture-in-Picture";
    };
    command = "floating enable, sticky enable, opacity 0.7";
  }

  # Calculator
  {
    criteria.app_id = "org.gnome.Calculator";
    command = "floating enable, move position center";
  }
  {
    criteria.app_id = "qalculate-gtk";
    command = "floating enable, move position center";
  }

  # Audio controls
  {
    criteria.app_id = "com.saivert.pwvucontrol";
    command = "floating enable, move position center";
  }
  {
    criteria.app_id = "pavucontrol";
    command = "floating enable, move position center";
  }
  {
    criteria.app_id = "pavucontrol-qt";
    command = "floating enable, move position center";
  }

  # Okular note dialog
  {
    criteria = {
      app_id = "org.kde.okular";
      title = "New Text Note — Okular";
    };
    command = "floating enable, move position center";
  }

  # PolicyKit agent
  {
    criteria.app_id = "lxqt-policykit-agent";
    command = "floating enable";
  }

  # Zoom rules
  {
    criteria.app_id = "^zoom.*";
    command = "floating enable";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^zoom$";
    };
    command = "border none, floating enable, move position mouse";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^(Zoom|About)$";
    };
    command = "border pixel, floating enable, move position mouse";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "Settings";
    };
    command = "floating enable, floating_minimum_size 960 x 700, move position mouse";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "Choose ONE of the audio conference options";
    };
    command = "floating enable, move position mouse";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^Zoom Meeting$";
    };
    command = "move container to workspace current, floating disable, inhibit_idle open";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^Zoom Meeting ID.*";
    };
    command = "move container to workspace current, floating disable, inhibit_idle open";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^as_toolbar$";
    };
    command = "floating enable, move position mouse";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^zoom_linux_float_video_window$";
    };
    command = "floating enable, move position mouse";
  }
  {
    criteria = {
      app_id = "^zoom.*";
      title = "^Zoom Meeting Control.*";
    };
    command = "floating enable, move position mouse";
  }

  # JetBrains rules
  {
    criteria = {
      class = "^jetbrains-.+";
      title = "^win[0-9]+$";
    };
    command = "floating enable, border none, move position mouse";
  }
  {
    criteria = {
      app_id = "^jetbrains-.+";
      title = "^win[0-9]+$";
    };
    command = "floating enable, border none, move position mouse";
  }
  {
    criteria = {
      class = "^jetbrains-.+";
      title = "^$";
    };
    command = "floating enable, border none, move position mouse";
  }
  {
    criteria = {
      app_id = "^jetbrains-.+";
      title = "^$";
    };
    command = "floating enable, border none, move position mouse";
  }
  {
    criteria = {
      class = "^jetbrains-.+";
      window_role = "splash";
    };
    command = "floating enable";
  }
  {
    criteria = {
      app_id = "^jetbrains-.+";
      window_role = "splash";
    };
    command = "floating enable";
  }
  {
    criteria = {
      class = "^jetbrains-.+";
      title = "^Welcome to .+";
    };
    command = "floating enable";
  }
  {
    criteria = {
      app_id = "^jetbrains-.+";
      title = "^Welcome to .+";
    };
    command = "floating enable";
  }
  {
    criteria = {
      app_id = "^jetbrains-.+";
      title = "^Gateway to .+";
    };
    command = "floating enable";
  }

  # Tooltips
  {
    criteria.window_type = "tooltip";
    command = "floating enable, border none";
  }
]
