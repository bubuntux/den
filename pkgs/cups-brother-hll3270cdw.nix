{
  stdenv,
  lib,
  fetchurl,
  perl,
  gnused,
  dpkg,
  makeWrapper,
  autoPatchelfHook,
  libredirect,
}:

stdenv.mkDerivation rec {
  pname = "cups-brother-hll3270cdw";
  version = "1.0.2";
  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf103926/hll3270cdwpdrv-${version}-0.i386.deb";
    sha256 = "f811a5fee775a3717fe725fc3f838b4f3e1bb9cecb00c93e4ae7e91bca7b40eb";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    perl
    gnused
    libredirect
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -pr opt "$out"
    cp -pr usr/bin "$out/bin"
    rm "$out/opt/brother/Printers/hll3270cdw/cupswrapper/cupswrapperhll3270cdw"

    mkdir -p "$out/lib/cups/filter" "$out/share/cups/model"

    ln -s "$out/opt/brother/Printers/hll3270cdw/cupswrapper/brother_lpdwrapper_hll3270cdw" \
      "$out/lib/cups/filter/brother_lpdwrapper_hll3270cdw"
    ln -s "$out/opt/brother/Printers/hll3270cdw/cupswrapper/brother_hll3270cdw_printer_en.ppd" \
      "$out/share/cups/model/brother_hll3270cdw_printer_en.ppd"

    runHook postInstall
  '';

  postFixup = ''
    substituteInPlace $out/opt/brother/Printers/hll3270cdw/lpd/filter_hll3270cdw \
      --replace "my \$BR_PRT_PATH =" "my \$BR_PRT_PATH = \"$out/opt/brother/Printers/hll3270cdw/\"; #" \
      --replace "PRINTER =~" "PRINTER = \"hll3270cdw\"; #"

    substituteInPlace $out/opt/brother/Printers/hll3270cdw/cupswrapper/brother_lpdwrapper_hll3270cdw \
      --replace "PRINTER =~" "PRINTER = \"hll3270cdw\"; #" \
      --replace "my \$basedir = \`readlink \$0\`" "my \$basedir = \"$out/opt/brother/Printers/hll3270cdw/\""

    wrapProgram $out/bin/brprintconf_hll3270cdw \
      --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS /opt=$out/opt

    wrapProgram $out/opt/brother/Printers/hll3270cdw/lpd/brhll3270cdwfilter \
      --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS /opt=$out/opt

    substituteInPlace $out/bin/brprintconf_hll3270cdw \
      --replace \"\$"@"\" \"\$"@\" | LD_PRELOAD= ${gnused}/bin/sed -E '/^(function list :|resource file :).*/{s#/opt#$out/opt#}'"
  '';

  meta = {
    description = "Brother HL-L3270CDW printer driver";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "i686-linux"
    ];
    homepage = "http://www.brother.com/";
    downloadPage = "https://support.brother.com/g/b/downloadend.aspx?c=us&lang=en&prod=hll3270cdw_us_eu_as&os=128&dlid=dlf103926_000&flang=4&type3=10283";
  };
}
