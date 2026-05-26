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
      # nixpkgs and bind-mount the resolved store paths directly into the
      # container. The pip-in-container approach the upstream tvhlink guide
      # recommends would (a) require internet on container start,
      # (b) drift from any pinned version, and (c) bury the SOCKS proxy flag
      # in a /config/.config file that's easy to lose. Two muxes wrappers,
      # picked per-mux in the tvheadend UI:
      #
      #   pipe:///etc/tvheadend/streamlink-vpn ...   -> via wg-tvh exit
      #   pipe:///etc/tvheadend/streamlink     ...   -> direct, no VPN
      #
      # The container binds /nix/store ro so the wrapper's shebang chain
      # (bash -> streamlink -> python3 -> site-packages) resolves entirely
      # inside it.
      #
      # socks5h (with the trailing `h`) makes microsocks resolve DNS inside
      # the namespace too — without it streamlink would still leak hostname
      # lookups to the container's stub resolver.
      #
      # We bind the wrappers as individual file mounts instead of going
      # through `environment.etc` because the latter lays files down as
      # /etc/tvheadend/<x> -> /etc/static/tvheadend/<x> -> /nix/store/...,
      # and mounting /etc/tvheadend alone leaves a dangling symlink to
      # /etc/static inside the container. Direct file binds skip that hop.
      socksPort = 1080;
      socksHost = config.vpnNamespaces.wg-tvh.namespaceAddress;
      streamlinkVpn = pkgs.writeShellScriptBin "streamlink-vpn" ''
        exec ${pkgs.streamlink}/bin/streamlink \
          --http-proxy socks5h://${socksHost}:${toString socksPort} \
          "$@"
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
          # Streamlink: the runtime closure (python, ffmpeg, site-packages)
          # plus the two wrappers themselves. /nix/store is already
          # world-readable on the host; the wrappers are bound as files at
          # stable container paths so a `pipe:///etc/tvheadend/streamlink*`
          # mux command works without /etc/static gymnastics.
          "/nix/store:/nix/store:ro"
          "${pkgs.streamlink}/bin/streamlink:/etc/tvheadend/streamlink:ro"
          "${streamlinkVpn}/bin/streamlink-vpn:/etc/tvheadend/streamlink-vpn:ro"
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

      # The namespace's INPUT chain is DROP by default (vpn-up.nix:36). The
      # upstream module's only way to install an accept rule on the veth is
      # via `portMappings`, which ALSO installs a PREROUTING DNAT for
      # host_ip:from -> namespaceAddress:to. That DNAT is a no-op for
      # host-local sources (incl. the tvheadend container after podman NAT)
      # because PREROUTING isn't traversed for locally-originated packets,
      # so we still reach microsocks via the namespace IP directly — but
      # the INPUT allow rule the same option installs is mandatory.
      #
      # Side effect: anyone on the LAN dialing appa:1080 will be DNAT'd
      # into the namespace and gets an unauthenticated SOCKS5 relay through
      # the wg-tvh exit. Acceptable for a trusted home LAN; add a host
      # firewall rule blocking 1080 inbound on the LAN interface if that
      # changes.
      vpnNamespaces.wg-tvh.portMappings = [
        {
          from = socksPort;
          to = socksPort;
          protocol = "tcp";
        }
      ];

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
