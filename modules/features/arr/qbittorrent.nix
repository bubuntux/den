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
    in
    {
      imports = [ self.nixosModules.vpn-confinement ];

      services.qbittorrent = {
        enable = true;
        # Exposure is handled by the vpn-confinement namespace's portMappings.
        openFirewall = false;
        inherit webuiPort;
        serverConfig.Preferences.WebUI = {
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
