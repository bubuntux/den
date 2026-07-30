{
  flake.modules.nixos.podman =
    { config, ... }:
    let
      dockerEnabled = config.virtualisation.docker.enable;
    in
    {
      key = "den:nixos.podman";
      virtualisation.podman = {
        enable = true;
        autoPrune.enable = true;
        dockerCompat = !dockerEnabled;
        dockerSocket.enable = !dockerEnabled;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
}
