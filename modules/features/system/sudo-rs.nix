{
  flake.modules.nixos.sudo-rs = {
    key = "den:nixos.sudo-rs";
    security.sudo.enable = false;
    security.sudo-rs = {
      enable = true;
      execWheelOnly = true;
    };
  };
}
