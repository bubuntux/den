{
  flake.modules.nixos.audio =
    { lib, ... }:
    {
      key = "den:nixos.audio";
      security.rtkit.enable = true;
      services = {
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
          wireplumber.enable = true;
          extraConfig.pipewire."10-disable-x11-bell" = {
            "context.properties" = {
              "module.x11.bell" = false;
            };
          };
        };
        pulseaudio.enable = lib.mkForce false;
      };
    };
}
