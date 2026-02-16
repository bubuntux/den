{
  flake.homeModules.librewolf =
    { ... }:
    {
      programs.librewolf = {
        enable = true;
        policies = {
          ExtensionSettings = {
            "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
              installation_mode = "force_installed";
            };
            "sponsorBlocker@ajay.app" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
              installation_mode = "force_installed";
            };
            "{703be167-3be2-47ae-879b-55e2a2789dc8}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/proton-pass/latest.xpi";
              installation_mode = "force_installed";
            };
            "leechblockng@proginosko.com" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/leechblock-ng/latest.xpi";
              installation_mode = "force_installed";
            };
            "jid1-BoFifL9Vbdl2zQ@jetpack" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/decentraleyes/latest.xpi";
              installation_mode = "force_installed";
            };
            "{a222c366-6e32-4bdd-9812-c3c60e62fbc7}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-recommended-videos/latest.xpi";
              installation_mode = "force_installed";
            };
          };
        };
      };
    };
}
