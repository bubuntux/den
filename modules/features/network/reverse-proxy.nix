{ self, ... }:
{
  flake.modules.nixos.reverse-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.reverse-proxy;

      # LAN allowlist + loopback, formatted for Caddy's `client_ip` matcher
      # (space-separated IPv4 and IPv6 CIDRs). The LAN portion comes from
      # the shared `self.lib.lan` value so SSH, Caddy, and any other
      # consumer stay in sync.
      lanClientIps = lib.concatStringsSep " " (
        self.lib.lan.ipv4
        ++ self.lib.lan.ipv6
        ++ [
          "127.0.0.0/8"
          "::1"
        ]
      );

      mkHosts =
        name: aliases:
        lib.concatStringsSep " " ([ "${name}.{$BASE_DOMAIN}" ] ++ map (a: "${a}.{$BASE_DOMAIN}") aliases);

      mkRateLimit =
        name: rl:
        lib.optionalString (rl != null) ''
          rate_limit {
            zone ${name}_rate {
              match {
                path ${lib.concatStringsSep " " rl.paths}
              }
              key {client_ip}
              events ${toString rl.events}
              window ${rl.window}
            }
          }
        '';

      mkRoute =
        name: route:
        let
          hostList = mkHosts name route.aliases;
          proxy =
            if route.proxyConfig != "" then
              ''
                reverse_proxy ${route.upstreamAddr}:${toString route.port} {
                  ${route.proxyConfig}
                }
              ''
            else
              "reverse_proxy ${route.upstreamAddr}:${toString route.port}";
          body =
            mkRateLimit name route.rateLimit
            + lib.optionalString (route.extraConfig != "") (route.extraConfig + "\n")
            + proxy;
        in
        if route.public then
          ''
            @${name} host ${hostList}
            handle @${name} {
              ${body}
            }
          ''
        else
          ''
            @${name} host ${hostList}
            handle @${name} {
              @${name}-lan client_ip ${lanClientIps}
              handle @${name}-lan {
                ${body}
              }
              respond "Not found" 404
            }
          '';

      routes = lib.concatStrings (lib.mapAttrsToList mkRoute cfg.routes);
    in
    {
      key = "den:nixos.reverse-proxy";
      imports = [ self.modules.nixos.sops ];

      options.services.reverse-proxy = {
        enable = lib.mkEnableOption "Caddy reverse proxy with wildcard TLS";

        routes = lib.mkOption {
          description = ''
            Per-service routing table. Each entry produces a Caddy `@name`
            matcher that proxies `<name>.<domain>` (and any aliases) to a
            local upstream. Services declare their own entry here so the
            reverse-proxy module stays unaware of which backends exist.
          '';
          default = { };
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                port = lib.mkOption {
                  type = lib.types.port;
                  description = "Upstream port Caddy dials on `upstreamAddr`.";
                };
                upstreamAddr = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1";
                  description = ''
                    IP address Caddy dials for this route. Defaults to host
                    loopback. For services running inside a VPN network
                    namespace (vpn-confinement), set this to the namespace's
                    veth IP — e.g. `config.vpnNamespaces.wg.namespaceAddress`
                    — because VPN-Confinement only installs PREROUTING DNAT,
                    which doesn't catch loopback traffic from Caddy itself.
                  '';
                };
                aliases = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Extra short subdomains routed to the same backend.";
                };
                public = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    When false (default) only requests from RFC1918 /
                    loopback ranges reach the upstream; everything else gets
                    a 404. Set true to expose the service to the public
                    internet.
                  '';
                };
                rateLimit = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        paths = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          description = ''
                            Caddy path patterns matched for rate limiting.
                            Supports wildcards (`/foo/*`).
                          '';
                        };
                        events = lib.mkOption {
                          type = lib.types.ints.positive;
                          default = 5;
                          description = "Max events per window per client IP.";
                        };
                        window = lib.mkOption {
                          type = lib.types.str;
                          default = "1m";
                          description = "Time window (Caddy duration string).";
                        };
                      };
                    }
                  );
                  default = null;
                  description = ''
                    Per-client-IP rate limit on specific paths. Requires the
                    mholt/caddy-ratelimit plugin in the Caddy build. Excess
                    requests get 429 Too Many Requests.
                  '';
                };
                extraConfig = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = ''
                    Raw Caddyfile directives inserted into the handle block
                    before `reverse_proxy`. Use for request_body limits,
                    per-route headers, redirects, etc.
                  '';
                };
                proxyConfig = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = ''
                    Raw Caddyfile directives inserted inside the
                    `reverse_proxy { ... }` block. Use for flush_interval,
                    transport timeouts, lb_policy, etc.
                  '';
                };
              };
            }
          );
        };
      };

      config = lib.mkIf cfg.enable {
        # env-file format: BASE_DOMAIN=..., CLOUDFLARE_API_TOKEN=..., ACME_EMAIL=...
        # Loaded by Caddy's systemd unit before the process starts; the
        # placeholders below ({$VAR}) are substituted by Caddy at Caddyfile
        # parse time, so the domain itself never lands in the Nix store.
        sops.secrets.caddy_env = {
          sopsFile = "${self}/secrets/appa.yaml";
          restartUnits = [ "caddy.service" ];
        };

        services.caddy = {
          enable = true;

          # Custom build picks up three plugins:
          #   * caddy-dns/cloudflare — DNS-01 challenge for wildcard cert
          #   * hslatman/caddy-crowdsec-bouncer — HTTP-layer ban enforcement
          #   * mholt/caddy-ratelimit — per-IP rate limits on auth endpoints
          # When bumping any plugin version, set hash to lib.fakeHash,
          # rebuild, and copy the real hash from the error.
          package = pkgs.caddy.withPlugins {
            plugins = [
              "github.com/caddy-dns/cloudflare@v0.2.4"
              "github.com/hslatman/caddy-crowdsec-bouncer@v0.13.1"
              "github.com/mholt/caddy-ratelimit@v0.1.0"
            ];
            hash = "sha256-oeFflQ9ALULOVNKfuCb03nV6V4u467iu68mO/5BTFVw=";
          };

          environmentFile = config.sops.secrets.caddy_env.path;

          # email is for the Let's Encrypt account (cert expiry warnings); not
          # leaked in certs or CT logs. Read at startup from the env file.
          email = "{$ACME_EMAIL}";

          globalConfig = ''
            order crowdsec first
            order rate_limit before basic_auth

            crowdsec {
              api_url http://127.0.0.1:6868
              api_key {env.CROWDSEC_CADDY_API_KEY}
              ticker_interval 15s
            }
          '';

          # One wildcard site block, routed by @host matchers below.
          #
          # Access logs go to stdout, not the default per-vhost file: those are
          # mode 0600 and crowdsec's dynamic user cannot read them, so its
          # file-glob acquisition sat silently empty.
          virtualHosts."*.{$BASE_DOMAIN}".logFormat = ''
            output stdout
          '';

          virtualHosts."*.{$BASE_DOMAIN}".extraConfig = ''
            tls {
              dns cloudflare {env.CLOUDFLARE_API_TOKEN}
            }

            # CrowdSec bouncer: checks every request against the agent's
            # decision list (community blocklist + locally-detected bans).
            # Banned IPs get 403 here, before any route matches.
            crowdsec

            encode zstd gzip

            header {
              Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
              X-Content-Type-Options "nosniff"
              X-Frame-Options "SAMEORIGIN"
              Referrer-Policy "strict-origin-when-cross-origin"
            }

            ${routes}
            respond "Not found" 404
          '';

          # TCP 80 (HTTP→HTTPS redirect) + TCP 443 (HTTPS).
          openFirewall = true;
        };

        # HTTP/3 (QUIC) needs UDP 443; openFirewall above only handles TCP.
        networking.firewall.allowedUDPPorts = [ 443 ];

        # `--output=cat` is load-bearing: without it the syslog-prefixed line
        # reaches caddy-logs' UnmarshalJSON and fails on the timestamp. Other
        # acquisitions grok the prefixed line and keep it.
        services.crowdsec.hub.collections = [ "crowdsecurity/caddy" ];
        services.crowdsec.localConfig.acquisitions = [
          {
            source = "journalctl";
            journalctl_filter = [
              "_SYSTEMD_UNIT=caddy.service"
              "--output=cat"
            ];
            labels.type = "caddy";
          }
        ];

        # Ephemeral VM state would re-issue certs every boot and burn the Let's
        # Encrypt rate limit, so use Caddy's internal CA and forward 80/443 to
        # unprivileged host ports. Everything else matches production.
        #
        # Pair with /etc/hosts on the host:
        #   127.0.0.1 sonarr.<BASE_DOMAIN> jellyfin.<BASE_DOMAIN> ...
        # then hit https://sonarr.<BASE_DOMAIN>:1443
        virtualisation.vmVariant = {
          virtualisation.forwardPorts = [
            {
              from = "host";
              host.port = 18080;
              guest.port = 80;
            }
            {
              from = "host";
              host.port = 1443;
              guest.port = 443;
            }
          ];

          # HSTS intentionally dropped: with the internal CA, sending it
          # would pollute browser HSTS state for the real domain.
          services.caddy.virtualHosts."*.{$BASE_DOMAIN}".extraConfig = lib.mkForce ''
            tls internal

            crowdsec

            encode zstd gzip

            header {
              X-Content-Type-Options "nosniff"
              X-Frame-Options "SAMEORIGIN"
              Referrer-Policy "strict-origin-when-cross-origin"
            }

            ${routes}
            respond "Not found" 404
          '';
        };
      };
    };
}
