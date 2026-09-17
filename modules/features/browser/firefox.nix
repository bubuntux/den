{ self, lib, ... }:
let
  # LibreWolf-style hardening. Which mechanism a pref goes through matters:
  # `preferences` is the enterprise policy, which honours an allowlist of
  # prefixes and SILENTLY drops the rest, so anything outside it goes through
  # `autoConfig` as defaultPref (which also keeps it user-tweakable). A few
  # things neither sets cleanly have dedicated policies.

  # -- Allowlisted prefs (honored by the Preferences policy) ------------------

  # Tier 1 — clean new-tab page, no sponsored/Pocket/recommendation content.
  # (Sponsored shortcuts/stories are LOCKED off in lockedPrefs, not here.)
  annoyances = {
    "browser.discovery.enabled" = false;
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

  # SELECTED — disable AI/ML feature toggles. Belt-and-suspenders alongside the
  # AIControls policy below, which is the authoritative locked kill switch.
  ai = {
    "browser.ml.enable" = false;
    "browser.ml.chat.enabled" = false;
    "browser.ml.chat.menu" = false;
    "browser.ml.chat.shortcuts" = false;
    "browser.ml.chat.shortcuts.custom" = false;
    "browser.ml.chat.sidebar" = false;
    "browser.ml.linkPreview.enabled" = false;
    "browser.tabs.groups.smart.enabled" = false;
    "browser.tabs.groups.smart.userEnabled" = false;
    "pdfjs.enableAltText" = false;
    "pdfjs.enableAltTextModelDownload" = false;
    "extensions.ui.mlmodel.hidden" = true;
    "browser.preferences.aiControls" = false;
  };

  # SELECTED — Firefox Home layout: usage-based shortcut tiles, 2 rows, no
  # weather widget (which queries Merino for the configured location).
  homeLayout = {
    "browser.newtabpage.activity-stream.feeds.topsites" = true;
    "browser.newtabpage.activity-stream.topSitesRows" = 2;
    "browser.newtabpage.activity-stream.showWeather" = false;
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
    // dns
    // ai
    // homeLayout;

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

  # -- Prefs we want ENFORCED (locked) via autoconfig `lockPref` --------------
  # Unlike the `default`-status prefs above, lockPref OVERRIDES any value your
  # existing profile already has AND greys the toggle out so it can't be
  # re-enabled. Use only for things you never want on.
  lockedPrefs = {
    # "Automatically send crash reports" — off, enforced.
    "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
    # Sponsored shortcuts + sponsored stories (the "supports Firefox" content).
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
  };

  # -- LeechBlock NG ----------------------------------------------------------
  # Shipped through the 3rdparty policy, which Firefox surfaces to the add-on as
  # `storage.managed`. LeechBlock copies that over its local storage on every
  # background-script start (`checkManagedStorage`), so these values are
  # enforced rather than seeded: edits made in its own UI are undone on the next
  # wake.

  # `days<N>` is a seven-element array indexed from Sunday.
  weekdays = [
    false
    true
    true
    true
    true
    true
    false
  ];
  everyDay = builtins.genList (_: true) 7;

  blockSets = [
    {
      setName = "Work hours";
      sites = [
        "news.ycombinator.com"
        "x.com"
        "youtube.com"
      ];
      times = "0900-1700";
      days = weekdays;
    }
    {
      setName = "Daily budget";
      sites = [ "reddit.com" ];
      limitMins = "30";
      limitPeriod = "86400";
      days = everyDay;
    }
  ];

  # LeechBlock matches URLs against the compiled `blockRE<N>` and recompiles it
  # from `sites<N>` only when its options page is saved, so a managed site list
  # shipped without one blocks nothing. Mirrors `getRegExpSites` /
  # `patternToRegExp` (common.js) for plain domains, with `matchSubdomains` on.
  blockRegExp =
    sites:
    let
      escaped = site: builtins.replaceStrings [ "." ] [ "\\." ] (lib.removePrefix "www." site);
    in
    "^(https?|file):\\/+([\\w:]+@)?("
    + lib.concatMapStringsSep "|" (site: "([^/]*\\.)?${escaped site}") sites
    + ")";

  leechblockSettings = {
    numSets = toString (builtins.length blockSets);
    matchSubdomains = true;
    # A set with no time limit counts down to the start of its next blocking
    # window instead, so without a ceiling its timer is on screen all day.
    timerMaxHours = "1";
    # Stops the per-second sweep refreshing `tab.audible` for background tabs,
    # so a set that ever turns on countAudio would undercount.
    processActiveTabs = true;
  }
  // lib.mergeAttrsList (
    lib.imap1 (set: opts: {
      "setName${toString set}" = opts.setName;
      "sites${toString set}" = lib.concatStringsSep " " opts.sites;
      "blockRE${toString set}" = blockRegExp opts.sites;
      "times${toString set}" = opts.times or "";
      "limitMins${toString set}" = opts.limitMins or "";
      "limitPeriod${toString set}" = opts.limitPeriod or "";
      "days${toString set}" = opts.days;
      # Off by default, and then a page already open when the window opens or
      # the budget runs out stays usable until the next navigation.
      "activeBlock${toString set}" = true;
    }) blockSets
  );
in
{
  flake.modules = {
    nixos.firefox =
      {
        pkgs,
        lib,
        ...
      }:
      {
        key = "den:nixos.firefox";
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
            ++ lib.mapAttrsToList (
              name: value: "lockPref(${builtins.toJSON name}, ${builtins.toJSON value});"
            ) lockedPrefs
          );

          policies = {
            # Canonical switches the Preferences policy can't set:
            DisableTelemetry = true; # toolkit.telemetry.*, Normandy, Shield, datareporting
            DisableFirefoxAccounts = true; # disables Sync / Mozilla account
            Certificates.ImportEnterpriseRoots = false; # ignore OS/enterprise roots (mostly a no-op on Linux)

            # Disable + hard-lock all AI features (authoritative kill switch,
            # FF 149+). Flip Translations to "available" to allow local translation.
            AIControls = {
              Default = {
                Value = "blocked";
                Locked = true;
              };
              SidebarChatbot = {
                Value = "blocked";
                Locked = true;
              };
              SmartTabGroups = {
                Value = "blocked";
                Locked = true;
              };
              SmartWindow = {
                Value = "blocked";
                Locked = true;
              };
              LinkPreviewKeyPoints = {
                Value = "blocked";
                Locked = true;
              };
              PDFAltText = {
                Value = "blocked";
                Locked = true;
              };
              Translations = {
                Value = "blocked";
                Locked = true;
              };
            };

            # Force-installed extensions (cannot be disabled/removed via the UI).
            # LibreWolf bundles uBlock Origin; the rest are your requested set.
            # `extra` per extension:
            #   default_area   = "navbar" (pinned to main toolbar) | "menupanel" (overflow ≡ menu)
            #   private_browsing = true  (allowed to run in private windows)
            # default_area sets the DEFAULT placement (applied on fresh profiles).
            ExtensionSettings =
              let
                amo = slug: "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
                forced =
                  slug: extra:
                  {
                    installation_mode = "force_installed";
                    install_url = amo slug;
                  }
                  // extra;
              in
              {
                "uBlock0@raymondhill.net" = forced "ublock-origin" {
                  default_area = "navbar";
                  private_browsing = true;
                };
                "78272b6fa58f4a1abaac99321d503a20@proton.me" = forced "proton-pass" {
                  default_area = "navbar";
                  private_browsing = true;
                };
                # Multi-Account Containers: create/manage containers + per-site
                # assignments. NOTE: assignments are stored in-profile (UI only) —
                # they cannot be declared here; set them once in its UI. Private
                # windows don't use containers, so no private_browsing.
                "@testpilot-containers" = forced "multi-account-containers" {
                  default_area = "navbar";
                };
                "sponsorBlocker@ajay.app" = forced "sponsorblock" {
                  default_area = "menupanel";
                  private_browsing = true;
                };
                "myallychou@gmail.com" = forced "youtube-recommended-videos" {
                  default_area = "menupanel";
                  private_browsing = true;
                };
                # Facebook Container auto-traps all Meta domains (FB/IG/Messenger/WhatsApp/Threads).
                "@contain-facebook" = forced "facebook-container" {
                  default_area = "menupanel";
                };
                # Google Container: only dedicated option on AMO, unmaintained since 2021.
                "@contain-google" = forced "google-container" {
                  default_area = "menupanel";
                };
                # navbar so the remaining-time badge stays visible; without
                # private_browsing a private window is a free pass.
                "leechblockng@proginosko.com" = forced "leechblock-ng" {
                  default_area = "navbar";
                  private_browsing = true;
                };
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

            "3rdparty".Extensions."leechblockng@proginosko.com" = leechblockSettings;
          };
        };
        xdg.mime.defaultApplications = {
          "text/html" = "firefox.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
        };
        home-manager.sharedModules = [ self.modules.homeManager.firefox ];
      };

    homeManager.firefox = {
      key = "den:homeManager.firefox";
      xdg.mimeApps.defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
    };
  };
}
