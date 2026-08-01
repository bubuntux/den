{ self, ... }:
{
  flake.modules.nixos.tvheadend =
    { config, pkgs, ... }:
    # Dropped from nixpkgs in PR #336395 for want of a maintainer, so this runs
    # the linuxserver image -- the only container on appa. Web/HTSP-HTTP on
    # 9981; binary HTSP on 9982 is unused (no Kodi clients on this LAN).
    let
      port = 9981;
      uid = 989;
      gid = 989;

      # Pipe-mux wrappers, picked per mux in the UI: streamlink-vpn goes out the
      # wg-tvh exit, streamlink direct. Installed on the host and bind-mounted
      # rather than pip-installed in the container, which would need network at
      # start and pin nothing.
      #
      # socks5h resolves DNS inside the namespace too; without the `h`,
      # hostname lookups leak to the container's stub resolver. Bound as
      # individual files because environment.etc leaves a dangling /etc/static
      # symlink inside the container.
      socksPort = 1080;
      socksHost = config.vpnNamespaces.wg-tvh.namespaceAddress;
      streamlinkVpn = pkgs.writeShellScriptBin "streamlink-vpn" ''
        exec ${pkgs.streamlink}/bin/streamlink \
          --http-proxy socks5h://${socksHost}:${toString socksPort} \
          "$@"
      '';

      # XMLTV grabber for the Spanish FTA channels; appears in Channel/EPG ->
      # EPG Grabber Modules after a rebuild. The image's own tv_grab_url takes
      # the URL positionally and tvheadend calls grabbers with no arguments, so
      # it silently produces nothing; this bakes the URL in and answers the
      # --description/--version/--capabilities probes.
      #
      # epgshare01 rather than open-epg, whose Spain bundles ship no <category>
      # elements at all, so nothing can classify programmes. Its channel ids are
      # dotted (Antena.3.es), so remap streamlink channels once after a switch.
      #
      # The guards are not paranoia: on 2026-05-26 an upstream served an HTML
      # error page with a 200 for a .gz path, and the bad payloads saturated
      # tvheadend's single spawn slot until the web UI stopped responding.
      # EPG is not geo-restricted, so this does not go through wg-tvh.
      tvGrabAtresplayer = pkgs.writeShellScriptBin "tv_grab_es_atresplayer" ''
        set -euo pipefail

        case "''${1:-}" in
          --description)  echo "Spain (Atresmedia community XMLTV)"; exit 0 ;;
          --version)      echo "1.0"; exit 0 ;;
          --capabilities) echo "baseline"; exit 0 ;;
        esac

        url=https://epgshare01.online/epgshare01/epg_ripper_ES1.xml.gz

        if ! out=$(${pkgs.curl}/bin/curl -fsSL --max-time 30 "$url" \
                   | ${pkgs.gzip}/bin/gunzip); then
          echo "tv_grab_es_atresplayer: fetch or gunzip of $url failed" >&2
          exit 1
        fi

        if [[ "$out" != '<?xml'* ]]; then
          echo "tv_grab_es_atresplayer: response is not XML (upstream change?)" >&2
          exit 1
        fi

        if [[ "$out" != *'<tv '* ]]; then
          echo "tv_grab_es_atresplayer: XML doesn't look like XMLTV (no <tv> root)" >&2
          exit 1
        fi

        printf '%s' "$out"
      '';
    in
    {
      key = "den:nixos.tvheadend";
      imports = with self.modules.nixos; [
        media-registry
        vpn-confinement-tvh
      ];

      den.media.services.tvheadend = {
        inherit port;
        # The service is the podman unit, not a native `tvheadend.service`.
        unit = "podman-tvheadend";
        # Or a missed mount writes into the root fs and shadows the bind later.
        requiresMounts = [
          "/mnt/config"
          "/mnt/media"
        ];
        # Like jellyfin/plex: streaming wins CPU contention over scanners.
        # Observed sub-200MB, capped above that against a runaway grabber.
        resources = {
          memoryHigh = "5%";
          memoryMax = "10%";
          cpuWeight = 150;
          ioWeight = 150;
        };
      };

      users.users.tvheadend = {
        isSystemUser = true;
        group = "tvheadend";
        # video: read /dev/dvb adapter nodes (host udev rule sets GROUP=video).
        # (`media`, for writing into /mnt/media/recordings alongside the *arr
        # stack, comes from the registry.)
        extraGroups = [ "video" ];
        inherit uid;
      };
      users.groups.tvheadend.gid = gid;

      # The image builds its `abc` user from PUID but imports no supplementary
      # groups, so writing to /mnt/media/recordings needs --group-add by GID.
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
          # The streamlink closure; the wrappers are bound as files below.
          "/nix/store:/nix/store:ro"
          "${pkgs.streamlink}/bin/streamlink:/etc/tvheadend/streamlink:ro"
          "${streamlinkVpn}/bin/streamlink-vpn:/etc/tvheadend/streamlink-vpn:ro"
          # /usr/local/bin/ is on the LSIO image's PATH so tvheadend's
          # grabber discovery picks this up alongside the bundled tv_grab_*
          # scripts in /usr/bin/.
          "${tvGrabAtresplayer}/bin/tv_grab_es_atresplayer:/usr/local/bin/tv_grab_es_atresplayer:ro"
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

      # What streamlink-vpn points at: only the stream fetches are tunneled,
      # the container itself stays on the host network.
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

      # Only way to get an INPUT accept rule on the veth (the chain is DROP by
      # default); the DNAT it also installs is a no-op for local sources.
      #
      # Side effect: anyone on the LAN dialing appa:1080 gets an
      # unauthenticated SOCKS5 relay out the wg-tvh exit. Acceptable on a
      # trusted LAN -- block 1080 inbound if that changes.
      vpnNamespaces.wg-tvh.portMappings = [
        {
          from = socksPort;
          to = socksPort;
          protocol = "tcp";
        }
      ];

      systemd.tmpfiles.rules = [
        "d /mnt/config/tvheadend 0750 tvheadend tvheadend - -"
        # Setgid so new recordings inherit the media group -- matches the
        # /mnt/media/* layout the *arr stack relies on for cross-service
        # handoffs (see profile-nas.nix).
        "d /mnt/media/recordings 02775 tvheadend media   - -"
      ];

      services.reverse-proxy.routes.tvheadend = {
        aliases = [ "tv" ];
        # public defaults to false -- LAN-only, matches the *arr admin UIs.
      };
    };
}
