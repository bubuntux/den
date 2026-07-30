{ self, ... }:
{
  # Julio's laptop-as-daily-driver role: the stack katara and zuko both run.
  # Composes other profiles, which the layer table permits for exactly this
  # case -- the alternative is repeating an eight-module import list in every
  # host file.
  #
  # Gaming is deliberately NOT here. It was, and it made the role mean "the
  # union of what these two hosts happen to have" rather than one idea: katara
  # is a family machine that also carries this stack, and nobody games on it.
  # Steam, gamescope and the controller drivers are a capability, so the host
  # that wants them imports profile-gaming itself (zuko does).
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

    # Only the additive desktop settings; the greeter and the default session
    # are single-valued whole-machine policy and live on the host, so a host can
    # combine this with another role (katara pairs it with profile-family)
    # without two profiles fighting over one value.
    den.desktop = {
      environments = [ "sway" ];
      users.bbtux = "sway";
    };

    # Both workstations dock in clamshell (lid closed): never suspend on the lid.
    # (The lid switch is also disabled in the BIOS so the internal panel stays
    # available; this is the OS-side belt-and-suspenders.) swayidle still
    # suspends on idle (battery only) as the real sleep trigger. Host policy, so
    # it lives here rather than in the sway session module.
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  };
}
