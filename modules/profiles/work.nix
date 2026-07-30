{ self, ... }:
{
  flake.modules.nixos.profile-work = _: {
    imports = with self.modules.nixos; [
      wifi-work
      work-container
    ];
  };
}
