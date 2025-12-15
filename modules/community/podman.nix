{
  com.podman.nixos =
    { config, ... }:
    let
      dockerEnabled = config.virtualisation.docker.enable;
    in
    {
      # TODO if nvidia enabled
      hardware.nvidia-container-toolkit.enable = true;

      virtualisation.podman = {
        enable = true;
        autoPrune.enable = true;
        dockerCompat = !dockerEnabled;
        dockerSocket.enable = !dockerEnabled;
        defaultNetwork.settings.dns_enabled = true;
      };

    };

}
