{ self, ... }:
{
  # The stack katara and zuko both run. Composes other profiles, which the
  # layer table permits for exactly this case.
  #
  # Gaming is deliberately not here: it made the role mean "what these two
  # hosts happen to share" rather than one idea. zuko imports it directly.
  flake.modules.nixos.profile-workstation = {
    key = "den:nixos.profile-workstation";
    imports = with self.modules.nixos; [
      profile-laptop
      profile-work
      profile-developer
      bundle-desktop
      user-bbtux
      vpn
      firefox
      loupe
    ];

    home-manager.users.bbtux.imports = [ self.modules.homeManager.taskwarrior ];

    # Only the additive desktop setting; the greeter and the default session are
    # single-valued whole-machine policy and live on the host, so a host can
    # combine this with another role (katara pairs it with profile-family)
    # without two profiles fighting over one value.
    den.desktop.environments = [ "sway" ];

    # Both workstations dock in clamshell (lid closed): never suspend on the lid.
    # (The lid switch is also disabled in the BIOS so the internal panel stays
    # available; this is the OS-side belt-and-suspenders.) swayidle still
    # suspends on idle (battery only) as the real sleep trigger. Host policy, so
    # it lives here rather than in the sway session module.
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  };
}
