{ ... }:
{
  den.default.includes = [
    {
      nixos.system.stateVersion = "25.11";
      homeManager.home.stateVersion = "25.11";
    }
  ];
}
