{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.1.7";
  srcs = {
    x86_64-linux = {
      url = "https://github.com/zeroclaw-labs/zeroclaw/releases/download/v${version}/zeroclaw-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-tbJvBq9Zc7cgZlYZCpTfO9KkIr8tQv1tXaJaQvL29tA=";
    };
    aarch64-linux = {
      url = "https://github.com/zeroclaw-labs/zeroclaw/releases/download/v${version}/zeroclaw-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-iLXYhtdDg1Agcv+dYWEYDFTdEIh8FozebXx7L88rUW8=";
    };
  };
  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "zeroclaw";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 zeroclaw $out/bin/zeroclaw
    runHook postInstall
  '';

  meta = {
    description = "Fast, lightweight AI agent runtime written in Rust";
    homepage = "https://github.com/zeroclaw-labs/zeroclaw";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "zeroclaw";
  };
}
