{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  patchelf,
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

  nativeBuildInputs = [
    installShellFiles
    patchelf
  ];

  dontAutoPatchelf = true;

  installPhase = ''
    runHook preInstall

    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
      zeroclaw

    install -Dm755 zeroclaw $out/bin/zeroclaw

    installShellCompletion --cmd zeroclaw \
      --bash <($out/bin/zeroclaw completions bash) \
      --zsh <($out/bin/zeroclaw completions zsh) \
      --fish <($out/bin/zeroclaw completions fish)

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
