{
  # Single source of truth for how warm the screen goes after dark, shared by
  # every desktop that filters blue light: gammastep under Sway, Night Light
  # under GNOME. Exposed at the flake level rather than as a NixOS option
  # because it is a constant, not a per-host variant -- two desktops on the
  # same machine drifting apart is the failure worth preventing here.
  #
  # Only the night value needs stating. 6500K is the neutral point, which
  # gammastep(1) notes leaves the display untouched, so daytime is simply
  # uncorrected and GNOME has no daytime temperature at all. 3500K sits
  # mid-band of the 3000K-4000K that gammastep(1) recommends for night;
  # GNOME's own 2700K default is warmer than that band.
  flake.lib.nightLightKelvin = 3500;
}
