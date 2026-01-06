{
  ...
}:
{

  security.polkit.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      // Allow "wheel" users to use machinectl shell without authentication
      if (action.id == "org.freedesktop.machine1.shell" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  containers.work = {

    restartIfChanged = true;
    autoStart = false;
    ephemeral = true;

    allowedDevices = [
      {
        node = "/dev/net/tun";
        modifier = "rwm";
      } # VPNs
      {
        node = "/dev/fuse";
        modifier = "rwm";
      } # FUSE filesystems
      {
        node = "/dev/kvm";
        modifier = "rwm";
      } # VM acceleration
      {
        node = "/dev/dri";
        modifier = "rwm";
      } # GPU (Graphics)
      {
        node = "/dev/snd";
        modifier = "rwm";
      } # Sound cards (ALSA)
      {
        node = "/dev/input";
        modifier = "rwm";
      } # Mice, Keyboards, Gamepads
      {
        node = "/dev/bus/usb";
        modifier = "rwm";
      } # Raw USB devices (Arduino, etc)
    ];

    bindMounts = {
      "/run/user/1000" = {
        hostPath = "/run/user/1000";
        isReadOnly = false;
      };

      # (Optional) Shared memory is often needed by Wayland compositors
      "/dev/shm" = {
        hostPath = "/dev/shm";
        isReadOnly = false;
      };

      "/dev/net/tun" = {
        hostPath = "/dev/net/tun";
        isReadOnly = false;
      };
      "/dev/fuse" = {
        hostPath = "/dev/fuse";
        isReadOnly = false;
      };
      "/dev/kvm" = {
        hostPath = "/dev/kvm";
        isReadOnly = false;
      };
      "/dev/dri" = {
        hostPath = "/dev/dri";
        isReadOnly = false;
      };

      # For directories, binding the whole folder works great:
      "/dev/snd" = {
        hostPath = "/dev/snd";
        isReadOnly = false;
      };
      "/dev/input" = {
        hostPath = "/dev/input";
        isReadOnly = false;
      };
      "/dev/bus/usb" =
        {
          hostPath = "/dev/bus/usb";
          isReadOnly = false;
        }

      ;
    };

    config =
      { pkgs, ... }:
      {
        hardware.graphics.enable = true;

        # Install a test app
        environment.systemPackages = with pkgs; [
          wayland-utils # for wayland-info
          git

          xdg-desktop-portal
          xdg-desktop-portal-gtk
          xdg-desktop-portal-wlr
          firefox
        ];

        xdg.portal = {
          enable = true;
          extraPortals = [
            pkgs.xdg-desktop-portal-gtk
            pkgs.xdg-desktop-portal-wlr
          ];
          config.common.default = "*";
        };

        users.users.juliogm = {
          isNormalUser = true;
          uid = 1000;
          password = "password";
          extraGroups = [
            "video"
            "audio"
            "networkmanager"
            "input"
            "pipewire"
            "wheel"
          ];
        };

        # 4. Set Environment Variables for Wayland
        environment.sessionVariables = {
          # Tell apps where to find the socket we bound
          WAYLAND_DISPLAY = "wayland-1";
          XDG_SESSION_TYPE = "wayland";

          XDG_CURRENT_DESKTOP = "sway";

          XDG_RUNTIME_DIR = "/run/user/1000";
          PIPEWIRE_RUNTIME_DIR = "/run/user/1000";

          # Force specific toolkits to use Wayland
          QT_QPA_PLATFORM = "wayland";
          GDK_BACKEND = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
        };

      };

  };

}
