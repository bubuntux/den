{
  flake.nixosModules.sudors = _: {
    security.sudo.enable = false;
    security.sudo-rs = {
      enable = true;
      execWheelOnly = true;
    };
  };
}
