{ self, ... }:
{
  flake.nixosModules.profile-work = _: {
    imports = with self.nixosModules; [
      wifi-work
      work-container
    ];
  };
}
