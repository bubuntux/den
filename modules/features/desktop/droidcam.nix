_: {
  # Use a phone (Android/iOS) as a webcam via the DroidCam app.
  #
  # programs.droidcam.enable installs the droidcam client and loads v4l2loopback
  # (virtual /dev/video camera) + snd-aloop (virtual mic). Connect over WiFi (enter
  # the IP/port the DroidCam phone app shows) or USB. The virtual camera is a normal
  # V4L2 node, so unlike the built-in IPU6 cam it is not zoomed and can be bound into
  # containers. v4l2loopback loads at boot, so a reboot is needed after first enabling.
  flake.nixosModules.droidcam = _: {
    programs.droidcam.enable = true;

    # Without exclusive_caps the loopback advertises both output and capture, and
    # browsers (Firefox/Chrome) skip it -- so the virtual camera never appears. Force
    # capture-only and give it a recognizable label.
    boot.extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label=DroidCam
    '';
  };
}
