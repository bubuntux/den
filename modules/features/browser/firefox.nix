{ self, ... }:
let
  # LibreWolf-style hardening. Firefox delivers prefs by two mechanisms with
  # very different rules — this file routes each pref to the one that works:
  #
  #   * `programs.firefox.preferences`  -> Firefox's `Preferences` ENTERPRISE
  #     POLICY, which only honors an allowlist of pref prefixes and SILENTLY
  #     drops everything else (see Policies.sys.mjs `allowedPrefixes` /
  #     `allowedSecurityPrefs`). Only allowlisted prefs live here.
  #   * `programs.firefox.autoConfig`   -> a real autoconfig `.cfg` (no
  #     allowlist). Prefs outside the policy allowlist go here as
  #     `defaultPref(...)` so they still apply AND stay user-tweakable.
  #   * dedicated top-level policies (DisableTelemetry, DisableFirefoxAccounts,
  #     Certificates) cover things neither pref path sets cleanly.
  #
  # Toggle a category by removing its block from the relevant merge below.

  # -- Allowlisted prefs (honored by the Preferences policy) ------------------

  # Tier 1 — clean new-tab page, no sponsored/Pocket/recommendation content.
  annoyances = {
    "browser.discovery.enabled" = false;
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
    "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
    "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
    "browser.topsites.contile.enabled" = false;
    "extensions.htmlaboutaddons.recommendations.enabled" = false;
    "extensions.getAddons.showPane" = false;
    "browser.preferences.moreFromMozilla" = false;
    "browser.vpn_promo.enabled" = false;
  };

  # Tier 1 — no background phone-home to Mozilla, no default-browser nag.
  connectivity = {
    "network.connectivity-service.enabled" = false;
    "network.captive-portal-service.enabled" = false;
    "browser.shell.checkDefaultBrowser" = false;
    "dom.private-attribution.submission.enabled" = false;
  };

  # Tier 1 — privacy-friendly geolocation provider, no region tracking.
  geolocation = {
    "geo.provider.network.url" = "https://api.beacondb.net/v1/geolocate";
    "geo.provider.use_geoclue" = false;
    "browser.region.network.url" = "";
    "browser.region.update.enabled" = false;
  };

  # Tier 2 (low risk) — no prefetch/speculative connections, trimmed referer.
  # (URL query-param stripping lives in autoConfigPrefs — not allowlisted.)
  netPrivacy = {
    "network.prefetch-next" = false;
    "network.dns.disablePrefetch" = true;
    "network.http.speculative-parallel-limit" = 0;
    "browser.places.speculativeConnect.enabled" = false;
    "browser.urlbar.speculativeConnect.enabled" = false;
    "network.http.referer.XOriginTrimmingPolicy" = 2;
  };

  # Tier 2 (low risk) — strict tracking protection, container tabs,
  # HTTPS-only (public only; local/LAN not force-upgraded), punycode display.
  trackingProtection = {
    "browser.contentblocking.category" = "strict";
    "privacy.userContext.enabled" = true;
    "privacy.userContext.ui.enabled" = true;
    "dom.security.https_only_mode" = true;
    "network.IDN_show_punycode" = true;
  };

  # Tier 2 (low risk) — no WebRTC/DNS leaks when proxying.
  webrtcDns = {
    "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
    "network.proxy.socks_remote_dns" = true;
  };

  # Tier 3 (SELECTED) — TLS hardening (allowlisted subset; cert-pinning/CRLite
  # live in autoConfigPrefs; enterprise-root trust is the Certificates policy).
  tlsHardening = {
    "security.OCSP.enabled" = 0;
    "security.OCSP.require" = false;
    "security.ssl.require_safe_negotiation" = true;
    "security.tls.enable_0rtt_data" = false;
  };

  # SELECTED — no built-in password manager / autofill (Sync off = the
  # DisableFirefoxAccounts policy).
  noPasswordManager = {
    "signon.rememberSignons" = false;
    "signon.autofillForms" = false;
    "signon.formlessCapture.enabled" = false;
    "extensions.formautofill.addresses.enabled" = false;
    "extensions.formautofill.creditCards.enabled" = false;
  };

  # SELECTED — no search/URL-bar suggestions (no keystrokes sent while typing).
  noSearchSuggestions = {
    "browser.search.suggest.enabled" = false;
    "browser.urlbar.suggest.searches" = false;
    "browser.urlbar.quicksuggest.enabled" = false;
    "browser.urlbar.trending.featureGate" = false;
    "browser.urlbar.weather.featureGate" = false;
  };

  # SELECTED — lighter fingerprinting protection (blocks known FP scripts
  # without RFP's forced light theme / fixed window / UTC side effects).
  fingerprinting = {
    "privacy.fingerprintingProtection" = true;
    "privacy.fingerprintingProtection.pbmode" = true;
  };

  # SELECTED — block audio+video autoplay; a click is required to start media.
  media = {
    "media.autoplay.default" = 5;
    "media.autoplay.blocking_policy" = 2;
  };

  # SELECTED — no JavaScript execution inside the built-in PDF viewer.
  pdf = {
    "pdfjs.enableScripting" = false;
  };

  # SELECTED — defer DNS to the system/VPN resolver; browser DoH explicitly
  # off (mode 5 also blocks Mozilla's automatic DoH rollout).
  dns = {
    "network.trr.mode" = 5;
  };

  policyPrefs =
    annoyances
    // connectivity
    // geolocation
    // netPrivacy
    // trackingProtection
    // webrtcDns
    // tlsHardening
    // noPasswordManager
    // noSearchSuggestions
    // fingerprinting
    // media
    // pdf
    // dns;

  # -- Prefs NOT on the Preferences-policy allowlist -> autoconfig .cfg --------
  # These would be silently dropped as policy prefs; deliver via autoConfig.
  autoConfigPrefs = {
    # Font substitutions (`font.name-list.*` is not allowlisted).
    "font.name-list.sans-serif.x-western" = "Roboto, Noto Sans, FiraCode Nerd Font Propo";
    "font.name-list.serif.x-western" = "Noto Serif, FiraCode Nerd Font Propo";
    "font.name-list.monospace.x-western" = "JetBrainsMono Nerd Font, FiraCode Nerd Font";
    "font.name-list.sans-serif.x-unicode" = "Roboto, Noto Sans, FiraCode Nerd Font Propo";
    "font.name-list.serif.x-unicode" = "Noto Serif, FiraCode Nerd Font Propo";
    "font.name-list.monospace.x-unicode" = "JetBrainsMono Nerd Font, FiraCode Nerd Font";

    # Tracking query-param stripping (`privacy.query_stripping.*` not allowlisted).
    "privacy.query_stripping.enabled" = true;
    "privacy.query_stripping.strip_list" =
      "gclid dclid fbclid mc_eid mc_cid twclid yclid __s igshid utm_source utm_medium utm_campaign utm_term utm_content";

    # TLS/cert hardening outside `allowedSecurityPrefs`.
    "security.cert_pinning.enforcement_level" = 2;
    "security.pki.crlite_mode" = 2;
    "security.remote_settings.crlite_filters.enabled" = true;
  };
in
{
  flake.nixosModules.firefox =
    {
      pkgs,
      lib,
      ...
    }:
    {
      programs.firefox = {
        enable = true;
        package = pkgs.firefox;

        # Allowlisted prefs, applied as tweakable defaults.
        preferencesStatus = "default";
        preferences = policyPrefs;

        # Non-allowlisted prefs, applied via autoconfig as tweakable defaults.
        autoConfig = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value: "defaultPref(${builtins.toJSON name}, ${builtins.toJSON value});"
          ) autoConfigPrefs
        );

        policies = {
          # Canonical switches the Preferences policy can't set:
          DisableTelemetry = true; # toolkit.telemetry.*, Normandy, Shield, datareporting
          DisableFirefoxAccounts = true; # disables Sync / Mozilla account
          Certificates.ImportEnterpriseRoots = false; # ignore OS/enterprise roots (mostly a no-op on Linux)

          # Force-installed extensions (cannot be disabled/removed via the UI).
          # LibreWolf bundles uBlock Origin; the rest are your requested set.
          ExtensionSettings =
            let
              amo = slug: "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
              forced = slug: {
                installation_mode = "force_installed";
                install_url = amo slug;
              };
            in
            {
              "uBlock0@raymondhill.net" = forced "ublock-origin";
              "78272b6fa58f4a1abaac99321d503a20@proton.me" = forced "proton-pass";
              "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = forced "vimium-ff";
              "sponsorBlocker@ajay.app" = forced "sponsorblock";
              "myallychou@gmail.com" = forced "youtube-recommended-videos";
              "leechblockng@proginosko.com" = forced "leechblock-ng";
              "@contain-facebook" = forced "facebook-container";
            };

          # Strip first-run / onboarding / promo surfaces.
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DisablePocket = true;
          NoDefaultBookmarks = true;
          UserMessaging = {
            WhatsNew = false;
            ExtensionRecommendations = false;
            FeatureRecommendations = false;
            UrlbarInterventions = false;
            MoreFromMozilla = false;
            SkipOnboarding = true;
          };

          # Preconfigure uBlock Origin's filter lists (declarative baseline).
          # `adminSettings.selectedFilterLists` SEEDS the selection and re-seeds
          # only when this list changes, so you can still toggle lists in the
          # uBO UI and keep them. For a hard-enforced set that resets on every
          # start instead, replace `adminSettings.selectedFilterLists` with
          # `toOverwrite.filterLists` (same list).
          "3rdparty".Extensions."uBlock0@raymondhill.net".adminSettings.selectedFilterLists = [
            "user-filters"
            "ublock-filters"
            "ublock-badware"
            "ublock-privacy"
            "ublock-unbreak"
            "ublock-quick-fixes"
            "easylist"
            "easyprivacy"
            "plowe-0"
            "urlhaus-1"
            "adguard-spyware-url"
            "fanboy-cookiemonster"
            "ublock-annoyances"
          ];
        };
      };
      xdg.mime.defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
      home-manager.sharedModules = [ self.homeModules.firefox ];
    };

  flake.homeModules.firefox = _: {
    xdg.mimeApps.defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
