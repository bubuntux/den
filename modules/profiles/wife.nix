{ self, ... }:
{
  flake.modules.nixos.profile-wife = {
    key = "den:nixos.profile-wife";
    imports = with self.modules.nixos; [
      user-shari
      gnome
      firefox
      openssh
    ];
  };
}
