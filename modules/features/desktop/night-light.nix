{
  # Shared by gammastep and GNOME Night Light so two desktops on one machine
  # cannot drift apart. A flake constant, not an option: it is not a per-host
  # variant. Only the night value needs stating -- 6500K is neutral, so daytime
  # is simply uncorrected. 3500K is mid-band of gammastep(1)'s recommendation.
  flake.lib.nightLightKelvin = 3500;
}
