{
  flake.nixosModules.audio =
    { lib, ... }:
    {
      security.rtkit.enable = true;
      services = {
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
          wireplumber.enable = true;
        };
        pulseaudio.enable = lib.mkForce false;
      };
    };
}
