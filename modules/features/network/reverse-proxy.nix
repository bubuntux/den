{ self, ... }:
{
  flake.nixosModules.reverse-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.reverse-proxy;

      mkHosts =
        name: aliases:
        lib.concatStringsSep " " ([ "${name}.{$BASE_DOMAIN}" ] ++ map (a: "${a}.{$BASE_DOMAIN}") aliases);

      mkRoute =
        name: route:
        let
          hostList = mkHosts name route.aliases;
          proxy =
            if route.proxyConfig != "" then
              ''
                reverse_proxy 127.0.0.1:${toString route.port} {
                  ${route.proxyConfig}
                }
              ''
            else
              "reverse_proxy 127.0.0.1:${toString route.port}";
          body = lib.optionalString (route.extraConfig != "") (route.extraConfig + "\n") + proxy;
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
              @${name}-lan client_ip 192.168.0.0/16 10.0.0.0/8 127.0.0.0/8
              handle @${name}-lan {
                ${body}
              }
              respond "Not found" 404
            }
          '';

      routes = lib.concatStrings (lib.mapAttrsToList mkRoute cfg.routes);
    in
    {
      imports = [ self.nixosModules.sops ];

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
                  description = "Local upstream port reached at 127.0.0.1.";
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

          # Custom build is required for DNS-01 — the Cloudflare provider isn't
          # in upstream Caddy. When bumping the plugin version, set hash to
          # lib.fakeHash, rebuild, and copy the real hash from the error.
          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
            hash = "sha256-hEIqK6F+9OCcd4JueVSidfUgQsVPWo0/imciD1UnqRo=";
          };

          environmentFile = config.sops.secrets.caddy_env.path;

          # email is for the Let's Encrypt account (cert expiry warnings); not
          # leaked in certs or CT logs. Read at startup from the env file.
          email = "{$ACME_EMAIL}";

          # Single wildcard site block. All routing happens via @host matchers
          # below; this is the canonical Caddy pattern for a wildcard cert.
          virtualHosts."*.{$BASE_DOMAIN}".extraConfig = ''
            tls {
              dns cloudflare {env.CLOUDFLARE_API_TOKEN}
            }

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
      };
    };
}
