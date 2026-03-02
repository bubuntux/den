{ self, ... }:
{
  flake.nixosModules.vpn-media =
    { config, lib, ... }:
    let
      cfg = config.den.vpn-media;
    in
    {
      imports = [ self.nixosModules.sops ];

      options.den.vpn-media = {
        wgAddress = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard interface address with CIDR (e.g. 10.2.0.2/32).";
        };

        wgDns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "10.2.0.1" ];
          description = "DNS servers to use inside the VPN container.";
        };

        wgPrivateKeyFile = lib.mkOption {
          type = lib.types.str;
          description = "Host path to the sops-decrypted WireGuard private key file.";
        };

        wgPeerPublicKey = lib.mkOption {
          type = lib.types.str;
          description = "WireGuard public key of the VPN peer (e.g. ProtonVPN server).";
        };

        wgPeerEndpoint = lib.mkOption {
          type = lib.types.str;
          description = "VPN peer endpoint as host:port.";
        };

        wgPeerAllowedIPs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "0.0.0.0/0"
            "::/0"
          ];
          description = "Allowed IPs for the WireGuard peer (default: route all traffic).";
        };

        hostAddress = lib.mkOption {
          type = lib.types.str;
          default = "10.200.200.1";
          description = "Host-side IP of the container veth pair.";
        };

        localAddress = lib.mkOption {
          type = lib.types.str;
          default = "10.200.200.2";
          description = "Container-side IP of the container veth pair.";
        };
      };

      config = {
        # Host-side networking: allow container traffic out
        boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
        networking.firewall.trustedInterfaces = [ "ve-+" ];
        networking.nat = {
          enable = true;
          internalInterfaces = [ "ve-+" ];
        };

        containers.vpn-media = {
          autoStart = true;
          privateNetwork = true;
          hostAddress = cfg.hostAddress;
          localAddress = cfg.localAddress;
          additionalCapabilities = [ "CAP_NET_ADMIN" ];

          forwardPorts = [
            {
              hostPort = 8080;
              containerPort = 8080;
              protocol = "tcp";
            }
            {
              hostPort = 9696;
              containerPort = 9696;
              protocol = "tcp";
            }
          ];

          bindMounts.wireguard-key = {
            hostPath = cfg.wgPrivateKeyFile;
            mountPoint = "/run/secrets-host/wireguard_private_key";
            isReadOnly = true;
          };

          config = {
            imports = with self.nixosModules; [
              qbittorrent
              prowlarr
            ];

            networking = {
              firewall.enable = false;
              useHostResolvConf = false;
              nameservers = cfg.wgDns;
              defaultGateway = cfg.hostAddress;

              wireguard.interfaces.wg0 = {
                ips = [ cfg.wgAddress ];
                privateKeyFile = "/run/secrets-host/wireguard_private_key";
                peers = [
                  {
                    publicKey = cfg.wgPeerPublicKey;
                    endpoint = cfg.wgPeerEndpoint;
                    allowedIPs = cfg.wgPeerAllowedIPs;
                    persistentKeepalive = 25;
                  }
                ];
              };
            };

            system.stateVersion = "25.11";
          };
        };
      };
    };
}
