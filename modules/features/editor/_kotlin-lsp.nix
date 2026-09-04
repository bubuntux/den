{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  freetype,
  libx11,
  libxext,
  libxi,
  libxkbcommon,
  libxrender,
  libxtst,
  maven,
  openjdk,
  wayland,
  zlib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "kotlin-lsp";
  version = "263.4421.0";

  src = fetchurl {
    url = "https://download-cdn.jetbrains.com/language-server/kotlin-server/${finalAttrs.version}/kotlin-server-${finalAttrs.version}.tar.gz";
    hash = "sha256-0dq073s5qI93zPaNXloWXJ88Xg+bG7mSPmJaVL08Zz8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    freetype
    libx11
    libxext
    libxi
    libxkbcommon
    libxrender
    libxtst
    stdenv.cc.cc
    wayland
    zlib
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/kotlin-lsp $out/bin
    cp -r . $out/share/kotlin-lsp

    makeWrapper $out/share/kotlin-lsp/bin/intellij-server $out/bin/kotlin-lsp \
      --suffix PATH : ${
        lib.makeBinPath [
          openjdk.home
          maven
        ]
      }

    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/Kotlin/kotlin-lsp";
    description = "JetBrains language server for Kotlin, built on the IntelliJ Kotlin plugin";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "kotlin-lsp";
    platforms = [ "x86_64-linux" ];
  };
})
