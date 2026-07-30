{
  flake.modules.nixos.sudors = {
    key = "den:nixos.sudors";
    security.sudo.enable = false;
    security.sudo-rs = {
      enable = true;
      execWheelOnly = true;
    };
  };
}
