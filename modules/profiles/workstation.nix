{ self, ... }:
{
  # Developer workstation stack (zuko). Composes other profiles, which the layer
  # table permits for exactly this case.
  #
  # Gaming is deliberately not here: a workstation is not a gaming rig even when
  # a host wants Steam. zuko imports it directly.
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

    # Only the additive desktop setting; the greeter and the default session are
    # single-valued whole-machine policy and live on the host, so a host can
    # combine this with another role without two profiles fighting over one
    # value.
    den.desktop.environments = [ "sway" ];

    # Workstations dock in clamshell (lid closed), so the lid must not suspend
    # on AC. (The lid switch is also disabled in the BIOS so the internal panel
    # stays available; this is the OS-side belt-and-suspenders.) On battery the
    # plain HandleLidSwitch default of "suspend" stands, and it is the only
    # thing that sleeps the machine now that swayidle carries no timeouts. Host
    # policy, so it lives here rather than in the sway session module.
    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  };
}
