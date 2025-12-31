{
  # environment.loginShellInit = ''
  #   if uwsm check may-start; then
  #     exec systemd-cat -t uwsm_start uwsm start default
  #   fi
  # '';
  # environment.sessionVariables = {
  #   UWSM_WAIT_VARNAMES = ["DISPLAY" "WAYLAND_DISPLAY "];
  #   UWSM_FINALIZE_VARNAMES = ["DISPLAY" "WAYLAND_DISPLAY "];
  # };
  security.pam.services.hyprlock.text = "auth include login";
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
}
