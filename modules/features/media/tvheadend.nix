{ self, ... }:
{
  flake.nixosModules.tvheadend =
    { config, pkgs, ... }:
    # Upstream tvheadend was dropped from nixpkgs in PR #336395 (2024-08-27)
    # after the 4.3 upgrade attempt found no maintainer. The linuxserver image
    # tracks current upstream and ships nightly DVB-capable builds, so we run
    # it via oci-containers. This is the only containerized service on appa
    # today -- if more containers land, hoist shared patterns (PUID wiring,
    # tmpfiles dirs) into a helper.
    #
    # Web/HTSP-HTTP on 9981 (jellyfin-plugin-tvheadend talks to this);
    # binary HTSP on 9982 is unused since Kodi clients aren't on this LAN.
    let
      port = 9981;
      uid = 989;
      gid = 989;

      # Streamlink (tvhlink-style pipe muxes): we install it on the host via
      # nixpkgs and expose it to the container through ro bind mounts of
      # /etc/tvheadend and /nix/store. The pip-in-container approach the
      # upstream tvhlink guide recommends would (a) require internet on
      # container start, (b) drift from any pinned version, and (c) bury the
      # SOCKS proxy flag in a /config/.config file that's easy to lose. Two
      # wrappers, picked per-mux in the tvheadend UI:
      #
      #   pipe:///etc/tvheadend/streamlink-vpn ...   -> via wg-tvh exit
      #   pipe:///etc/tvheadend/streamlink     ...   -> direct, no VPN
      #
      # socks5h (with the trailing `h`) makes microsocks resolve DNS inside
      # the namespace too — without it streamlink would still leak hostname
      # lookups to the container's stub resolver.
      socksPort = 1080;
      socksHost = config.vpnNamespaces.wg-tvh.namespaceAddress;
      streamlinkVpn = pkgs.writeShellScriptBin "streamlink-vpn" ''
        exec ${pkgs.streamlink}/bin/streamlink \
          --http-proxy socks5h://${socksHost}:${toString socksPort} \
          "$@"
      '';
      streamlinkPlain = pkgs.writeShellScriptBin "streamlink" ''
        exec ${pkgs.streamlink}/bin/streamlink "$@"
      '';
    in
    {
      imports = [ self.nixosModules.vpn-confinement-tvh ];

      users.users.tvheadend = {
        isSystemUser = true;
        group = "tvheadend";
        # video: read /dev/dvb adapter nodes (host udev rule sets GROUP=video).
        # media: write into /mnt/media/recordings alongside the *arr stack.
        extraGroups = [
          "video"
          "media"
        ];
        inherit uid;
      };
      users.groups.tvheadend.gid = gid;

      # Stable host paths the container sees verbatim. The .source = ...
      # symlink points into /nix/store, which is also bind-mounted into the
      # container, so the wrapper's shebang chain (bash -> streamlink ->
      # python3 -> site-packages) resolves entirely inside it.
      environment.etc = {
        "tvheadend/streamlink-vpn".source = "${streamlinkVpn}/bin/streamlink-vpn";
        "tvheadend/streamlink".source = "${streamlinkPlain}/bin/streamlink";
      };

      # lscr's tvheadend image sets up an in-container `abc` user at the PUID
      # we pass in, but it does NOT import the host user's supplementary
      # groups -- those have to be granted to the container runtime via
      # --group-add by numeric GID. Without this, the container can read
      # /dev/dvb (own group via PGID match below) but can't write into
      # /mnt/media/recordings (owned by the host `media` group).
      virtualisation.oci-containers.containers.tvheadend = {
        image = "lscr.io/linuxserver/tvheadend:latest";
        environment = {
          PUID = toString uid;
          PGID = toString gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "/mnt/config/tvheadend:/config"
          "/mnt/media/recordings:/recordings"
          # Host-installed streamlink wrappers + their nix closure. ro
          # because the container has no business writing here; /nix/store
          # is already world-readable on the host.
          "/etc/tvheadend:/etc/tvheadend:ro"
          "/nix/store:/nix/store:ro"
        ];
        # Bind the web port to loopback only; LAN access flows through caddy.
        # HTSP (9982) is intentionally not exposed -- no native HTSP clients
        # on this network, and the jellyfin plugin uses the HTTP API on 9981.
        ports = [ "127.0.0.1:${toString port}:${toString port}" ];
        extraOptions = [
          "--device=/dev/dvb:/dev/dvb"
          "--group-add=${toString config.users.groups.video.gid}"
          "--group-add=${toString config.users.groups.media.gid}"
        ];
      };

      # SOCKS5 daemon confined to the wg-tvh netns. The streamlink-vpn
      # wrapper points at this. The proxy's egress (the upstream connection
      # to the actual stream URL) exits via wg0 inside the namespace, so
      # the source sees the wg-tvh exit IP. The tvheadend container itself
      # stays on the host network — only the streamlink HTTP fetches are
      # tunneled.
      systemd.services.streamlink-socks = {
        description = "SOCKS5 proxy in the wg-tvh netns (streamlink egress)";
        wantedBy = [ "multi-user.target" ];

        vpnConfinement = {
          enable = true;
          vpnNamespace = "wg-tvh";
        };

        serviceConfig = {
          ExecStart = "${pkgs.microsocks}/bin/microsocks -i 0.0.0.0 -p ${toString socksPort}";
          DynamicUser = true;
          Restart = "always";
          RestartSec = "5s";
          # Bursty live streams can fan out a few dozen sockets; cap well
          # above the steady state so a bad day doesn't quietly OOM the
          # proxy and stall every streamlink mux at once.
          MemoryHigh = "64M";
          MemoryMax = "128M";
        };
      };

      # Recordings + EPG cache live under /mnt/media; defer container start
      # until both disks mount so a missed mount doesn't write into the
      # underlying root fs and shadow the bind later.
      systemd.services.podman-tvheadend = {
        unitConfig.RequiresMountsFor = [
          "/mnt/config"
          "/mnt/media"
        ];
        # Resource caps mirror jellyfin/plex: real-time streaming wins CPU
        # contention over scanners and downloaders. Tvheadend's memory
        # footprint is modest (sub-200MB observed in the lscr image) but
        # cap above that so a buggy EPG grabber can't drift unbounded.
        serviceConfig = {
          MemoryHigh = "5%";
          MemoryMax = "10%";
          CPUWeight = 150;
          IOWeight = 150;
        };
      };

      systemd.tmpfiles.rules = [
        "d /mnt/config/tvheadend 0750 tvheadend tvheadend - -"
        # Setgid so new recordings inherit the media group -- matches the
        # /mnt/media/* layout the *arr stack relies on for cross-service
        # handoffs (see profile-nas.nix).
        "d /mnt/media/recordings 02775 tvheadend media   - -"
      ];

      services.reverse-proxy.routes.tvheadend = {
        inherit port;
        aliases = [ "tv" ];
        # public defaults to false -- LAN-only, matches the *arr admin UIs.
      };

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = port;
          guest.port = port;
        }
      ];
    };
}
