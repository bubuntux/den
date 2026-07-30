{ self, ... }:
{
  flake.modules.nixos.profile-wife = _: {
    imports = with self.modules.nixos; [
      user-shari
      gnome
      firefox
      openssh
    ];
  };
}
