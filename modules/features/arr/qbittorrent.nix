{ self, ... }:
{
  flake.nixosModules.qbittorrent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      webuiPort = 8080;
      defaultSavePath = "/mnt/media/downloads";
      trackersURL = "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt";
      # qbittorrent stores QTime via Qt's QSettings INI writer as an
      # `@Variant(<8 bytes BE>)` blob: 4-byte type id (0x0f = QMetaType::QTime)
      # followed by 4-byte msec-since-midnight. Generated literally here so
      # the scheduler start/end times survive the upstream module's full
      # conf rewrite at every service start.
      mkQTimeVariant =
        h: m:
        let
          hex2 =
            n:
            let
              s = lib.toLower (lib.toHexString n);
            in
            if builtins.stringLength s < 2 then "0${s}" else s;
          ms = h * 3600000 + m * 60000;
          b3 = ms / 16777216;
          b2 = (ms / 65536) - b3 * 256;
          b1 = (ms / 256) - (ms / 65536) * 256;
          b0 = ms - (ms / 256) * 256;
        in
        "@Variant(\\x00\\x00\\x00\\x0f\\x${hex2 b3}\\x${hex2 b2}\\x${hex2 b1}\\x${hex2 b0})";
    in
    {
      imports = [ self.nixosModules.vpn-confinement ];

      services.qbittorrent = {
        enable = true;
        # Exposure is handled by the vpn-confinement namespace's portMappings.
        openFirewall = false;
        inherit webuiPort;
        # NOTE: the upstream module rewrites qBittorrent.conf from this
        # attrset on every service start (ExecStartPre install -Dm600), so
        # any setting changed via the WebUI is lost on rebuild/reboot. To
        # make a preference persist, declare it here.
        serverConfig = {
          Core.AutoDeleteAddedTorrentFile = "IfAdded";
          BitTorrent = {
            MergeTrackersEnabled = true;
            Session = {
              QueueingSystemEnabled = false;
              PerformanceWarning = true;
              DefaultSavePath = defaultSavePath;
              # Skip junk that rides along with media releases — *arrs
              # hardlink the wanted files out, so excluding these here just
              # avoids burning seed-tree space and inode count on samples,
              # nfos, archive parts, hashes, web-bait, and OS cruft.
              ExcludedFileNames = lib.concatStringsSep ", " [
                # text/info/release metadata
                "*.txt"
                "*.info"
                "*.diz"
                "*.nfo"
                # hash / checksum / parity
                "*.sfv"
                "*.md5"
                "*.sha1"
                "*.par2"
                # web bait
                "*.url"
                "*.html"
                "*.htm"
                "*.lnk"
                "*.link"
                # executables / scripts
                "*.exe"
                "*.bat"
                "*.sh"
                "*.scr"
                # archives & multi-part archives
                "*.rar"
                "*.r[0-9][0-9]"
                "*.part*.rar"
                "*.zip"
                "*.7z"
                "*.tar"
                "*.gz"
                "*.lzh"
                "*.arj"
                "*.lz"
                "*.iso"
                "*.001"
                # images
                "*.jpg"
                "*.jpeg"
                "*.png"
                "*.gif"
                "*.bmp"
                "*.webp"
                # samples
                "*sample*"
                # macOS / Windows cruft
                ".DS_Store"
                "Thumbs.db"
                "__MACOSX/*"
                "*.AppleDouble"
              ];
              # AutoTMM on by default; relocate files when the torrent's
              # category, category save path, or default save path change.
              DisableAutoTMMByDefault = false;
              DisableAutoTMMTriggers = {
                CategoryChanged = false;
                DefaultSavePathChanged = false;
                CategorySavePathChanged = false;
              };
              # Append trackers fetched from a public list to all new
              # public torrents. Setting the URL alone isn't enough --
              # AddTrackersFromURLEnabled is the master toggle.
              AddTrackersFromURLEnabled = true;
              AdditionalTrackersURL = trackersURL;
              # Alt upload cap = 1 MiB/s (KiB/s in conf), gated by the
              # bandwidth scheduler below to 9:00-18:00 Mon-Fri. DL=0
              # is qbittorrent's sentinel for "unlimited" -- the default
              # would otherwise be 10 KiB/s, which throttles downloads
              # too during the window.
              BandwidthSchedulerEnabled = true;
              AlternativeGlobalUPSpeedLimit = 1024;
              AlternativeGlobalDLSpeedLimit = 0;
            };
          };
          Preferences = {
            General.StatusbarExternalIPDisplayed = true;
            Scheduler = {
              days = "Weekday";
              start_time = mkQTimeVariant 9 0;
              end_time = mkQTimeVariant 18 0;
            };
            WebUI = {
              # Let the qbittorrent-natpmp sidecar update listen_port via the
              # Web API without credentials. Safe because the WebUI only binds
              # inside the wg netns.
              LocalHostAuth = false;
              # qbittorrent's HostHeaderValidation rejects any Host that isn't
              # its bind address; CSRFProtection rejects when Origin/Referer
              # don't match Host. Both misfire behind caddy, which preserves
              # the client hostname (qb.<BASE_DOMAIN>) rather than the
              # namespace IP. Disable both: TLS termination + SNI matching at
              # caddy already gate the requests, and AuthSubnetWhitelist
              # below scopes who can talk to the WebUI without a login.
              HostHeaderValidation = false;
              CSRFProtection = false;
              # Skip the WebUI login for trusted private ranges -- mirrors the
              # LocalHostAuth UX and matches the LAN whitelist used elsewhere.
              # 192.168.15.0/24 (the wg netns bridge) falls inside 192.168.0.0/16,
              # so caddy → namespace traffic is covered.
              AuthSubnetWhitelistEnabled = true;
              AuthSubnetWhitelist = lib.concatStringsSep "," (
                self.lib.lan.ipv4
                ++ self.lib.lan.ipv6
                ++ [
                  "127.0.0.0/8"
                  "::1"
                ]
              );
            };
          };
        };
      };

      users.users.qbittorrent.extraGroups = [ "media" ];

      # 0002 so files land 0664 / dirs 0775 -- combined with the setgid
      # bit on /mnt/media/*, radarr/sonarr (also in the media group) can
      # rename files out of qbittorrent's per-torrent subdirs after the
      # download completes. Default systemd umask 0022 strips group-write
      # and breaks the handoff.
      systemd.services.qbittorrent.serviceConfig.UMask = lib.mkForce "0002";

      # Defer service start until /mnt/media is mounted -- DefaultSavePath
      # lives under it. Without this the unit can start before the disk
      # mounts, writing torrents into the root fs and shadowing the mount.
      systemd.services.qbittorrent.unitConfig.RequiresMountsFor = [ "/mnt/media" ];

      # Resource caps (percent-of-RAM scales with hardware upgrades).
      # Active downloads + libtorrent disk caches have been observed near
      # 1.3 GB on appa. CPUWeight=50 — pure background work, must yield to
      # streams. The natpmp sidecar runs in this same slice via systemd's
      # parent-service grouping.
      systemd.services.qbittorrent.serviceConfig = {
        MemoryHigh = "8%";
        MemoryMax = "15%";
        CPUWeight = 50;
        IOWeight = 50;
      };

      # Seed the downloads directory with the same setgid/group layout as
      # the rest of /mnt/media so handoffs to the *arrs work out of the box.
      systemd.tmpfiles.rules = [
        "d ${defaultSavePath} 02775 qbittorrent media - -"
      ];

      services.reverse-proxy.routes.qbittorrent = {
        port = webuiPort;
        # vpn-confinement DNATs LAN-arriving traffic in PREROUTING, but
        # Caddy on the same host dials over loopback and bypasses that
        # rewrite. Point Caddy directly at the namespace veth IP.
        upstreamAddr = config.vpnNamespaces.wg.namespaceAddress;
        aliases = [
          "qb"
          "torrent"
        ];
      };

      # On-box alias so host-side services can dial qbittorrent without
      # hardcoding the namespace IP — same PREROUTING/OUTPUT reason as
      # the Caddy comment above. Use `http://qbittorrent.wg:8080`.
      networking.hosts.${config.vpnNamespaces.wg.namespaceAddress} = [ "qbittorrent.wg" ];

      systemd.services.qbittorrent.vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };

      vpnNamespaces.wg.portMappings = [
        {
          from = webuiPort;
          to = webuiPort;
          protocol = "tcp";
        }
      ];
      # No static openVPNPorts: qbittorrent-natpmp leases a port from the
      # VPN at runtime and opens it in the namespace's INPUT chain.

      systemd.services.qbittorrent-natpmp = {
        description = "NAT-PMP port forwarder for qBittorrent";
        wantedBy = [ "multi-user.target" ];
        after = [ "qbittorrent.service" ];
        wants = [ "qbittorrent.service" ];

        vpnConfinement = {
          enable = true;
          vpnNamespace = "wg";
        };

        path = with pkgs; [
          libnatpmp
          curl
          iptables
          iproute2
          gawk
          gnugrep
          coreutils
        ];

        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "10s";
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        };

        script = ''
          set -uo pipefail
          webui=http://127.0.0.1:${toString webuiPort}
          fw_port=0
          qb_port=0

          # Derive the NAT-PMP gateway from wg0's assigned address: most
          # WireGuard VPN providers (ProtonVPN, Mullvad, AzireVPN, ...) put
          # the NAT-PMP server at the .1 of the client's /24. If a provider
          # ever deviates from that, natpmpc errors will surface it here.
          addr=$(ip -4 -o addr show dev wg0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
          if [ -z "$addr" ]; then
            echo "wg0 has no IPv4 address; is wg.service up?" >&2
            exit 1
          fi
          gateway="$(echo "$addr" | cut -d. -f1-3).1"
          echo "deriving NAT-PMP gateway $gateway from wg0 address $addr"

          # Force the wg tunnel subnet via wg0 with a /24 override route.
          # The namespace's `accessibleFrom` rules can install broader routes
          # (e.g. 10.0.0.0/8 via the host bridge) that capture the VPN
          # gateway address, so NAT-PMP requests never reach the tunnel.
          subnet="$(echo "$addr" | cut -d. -f1-3).0/24"
          if ip route replace "$subnet" dev wg0; then
            echo "pinned $subnet via wg0 (override for accessibleFrom routes)"
          else
            echo "warn: failed to pin $subnet via wg0" >&2
          fi

          lease() {
            local proto=$1 out rc
            # Capture stdout; let stderr flow to the journal for diagnosis.
            out=$(natpmpc -a 1 0 "$proto" 60 -g "$gateway")
            rc=$?
            if [ $rc -ne 0 ]; then
              echo "natpmpc $proto failed (exit $rc)" >&2
              return 1
            fi
            printf '%s\n' "$out" | grep -m1 -oP 'Mapped public port \K[0-9]+'
          }

          while :; do
            tcp_port=$(lease tcp) || tcp_port=""
            udp_port=$(lease udp) || udp_port=""

            if [ -z "$tcp_port" ] || [ -z "$udp_port" ]; then
              echo "lease incomplete (tcp='$tcp_port' udp='$udp_port'); retrying in 10s" >&2
              sleep 10
              continue
            fi

            port=$tcp_port
            if [ "$tcp_port" != "$udp_port" ]; then
              echo "warn: tcp ($tcp_port) and udp ($udp_port) ports differ; using $port" >&2
            fi

            if [ "$port" != "$fw_port" ]; then
              echo "VPN assigned port $port (was $fw_port)"

              if [ "$fw_port" != "0" ]; then
                iptables -D INPUT -i wg0 -p tcp --dport "$fw_port" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -i wg0 -p udp --dport "$fw_port" -j ACCEPT 2>/dev/null || true
              fi
              iptables -I INPUT -i wg0 -p tcp --dport "$port" -j ACCEPT
              iptables -I INPUT -i wg0 -p udp --dport "$port" -j ACCEPT
              fw_port=$port
            fi

            if [ "$port" != "$qb_port" ]; then
              if curl -sf --max-time 5 \
                   --data-urlencode "json={\"listen_port\":$port}" \
                   "$webui/api/v2/app/setPreferences" >/dev/null
              then
                echo "qbittorrent listen_port updated to $port"
                qb_port=$port
              else
                echo "warn: failed to push port to qbittorrent (will retry)" >&2
              fi
            fi

            sleep 45
          done
        '';
      };

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = webuiPort;
          guest.port = webuiPort;
        }
      ];
    };
}
