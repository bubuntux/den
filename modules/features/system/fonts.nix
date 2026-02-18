{
  flake.nixosModules.fonts =
    { pkgs, ... }:
    {
      fonts = {
        fontDir.enable = true;
        # TODO bundle so it gets reused for home?
        packages = with pkgs; [
          liberation_ttf
          noto-fonts
          nerd-fonts.fira-code
          nerd-fonts.hack
          nerd-fonts.jetbrains-mono
          nerd-fonts.sauce-code-pro
          nerd-fonts.dejavu-sans-mono
        ];
      };
    };

  flake.homeModules.fonts =
    { pkgs, ... }:
    {
      fonts.fontconfig.enable = true;

      xdg.configFile."fontconfig/conf.d/99-defaults.conf".text = ''
        <?xml version='1.0'?>
        <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
        <fontconfig>
          <alias>
            <family>monospace</family>
            <prefer>
              <family>JetBrainsMono Nerd Font</family>
              <family>FiraCode Nerd Font</family>
              <family>DejaVuSansM Nerd Font</family>
            </prefer>
          </alias>
          <alias>
            <family>sans-serif</family>
            <prefer>
              <family>Roboto</family>
              <family>Noto Sans</family>
            </prefer>
          </alias>
          <alias>
            <family>serif</family>
            <prefer>
              <family>Noto Serif</family>
            </prefer>
          </alias>
          <match target="pattern">
            <test qual="any" name="family"><string>sans-serif</string></test>
            <edit name="family" mode="append"><string>Symbols Nerd Font</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>serif</string></test>
            <edit name="family" mode="append"><string>Symbols Nerd Font</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>monospace</string></test>
            <edit name="family" mode="append"><string>Symbols Nerd Font</string></edit>
          </match>
          <match target="font">
            <edit name="antialias" mode="assign"><bool>true</bool></edit>
            <edit name="hinting" mode="assign"><bool>true</bool></edit>
            <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
            <edit name="rgba" mode="assign"><const>rgb</const></edit>
            <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
          </match>
        </fontconfig>
      '';

      home.packages = with pkgs; [
        font-awesome
        roboto
        source-sans
        source-sans-pro
        nerd-fonts.symbols-only
        nerd-fonts.roboto-mono
        nerd-fonts.fira-code
        nerd-fonts.meslo-lg
        nerd-fonts.hack
        nerd-fonts.jetbrains-mono
        nerd-fonts.sauce-code-pro
        nerd-fonts.dejavu-sans-mono
      ];
    };
}
