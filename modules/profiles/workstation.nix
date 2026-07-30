{ self, ... }:
{
  # Julio's laptop-as-daily-driver role: the stack katara and zuko both run.
  # Composes other profiles, which the layer table permits for exactly this
  # case -- the alternative is repeating a nine-module import list in every
  # host file.
  flake.modules.nixos.profile-workstation = {
    key = "den:nixos.profile-workstation";
    imports = with self.modules.nixos; [
      profile-laptop
      profile-gaming
      profile-work
      profile-developer
      bundle-desktop
      user-bbtux
      vpn
      firefox
      loupe
    ];

    # Desktop selection. environments and loginManager are independent: add
    # "gnome" to environments to install it alongside sway and pick between them
    # at the greeter, or switch loginManager to gdm/lightdm without touching
    # either session.
    den.desktop = {
      environments = [ "sway" ];
      loginManager = "greetd";
      users.bbtux = "sway";
    };
    services.displayManager.defaultSession = "sway";

    # Both workstations dock in clamshell (lid closed): never suspend on the lid.
    # (The lid switch is also disabled in the BIOS so the internal panel stays
    # available; this is the OS-side belt-and-suspenders.) swayidle still
    # suspends on idle (battery only) as the real sleep trigger. Host policy, so
    # it lives here rather than in the sway session module.
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  };
}
