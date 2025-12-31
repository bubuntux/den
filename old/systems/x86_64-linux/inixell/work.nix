{ config, ... }:
let
  dockerEnabled = config.virtualisation.docker.enable;
in
{

  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia-container-toolkit.mount-nvidia-executables = true;

  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = !dockerEnabled;
    dockerSocket.enable = !dockerEnabled;
    defaultNetwork.settings.dns_enabled = true;
  };

}
