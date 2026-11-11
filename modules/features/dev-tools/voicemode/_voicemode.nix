{
  lib,
  alsa-lib,
  ffmpeg,
  gcc,
  libpulseaudio,
  pkg-config,
  portaudio,
  stdenv,
  uv,
  writeShellApplication,
}:
let
  version = "9.0.2";
  audioLibraries = [
    alsa-lib
    libpulseaudio
    portaudio
  ];
in
# Runs the PyPI release through uvx: nixpkgs' fastmcp is older than the
# >=3.4.10 voice-mode requires.
writeShellApplication {
  name = "voicemode";
  runtimeInputs = [
    ffmpeg
    gcc
    pkg-config
    uv
  ];
  # sounddevice dlopens portaudio; simpleaudio compiles against ALSA on first run.
  text = ''
    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath (audioLibraries ++ [ stdenv.cc.cc.lib ])
    }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PKG_CONFIG_PATH="${lib.makeSearchPathOutput "dev" "lib/pkgconfig" audioLibraries}"
    export CPATH="${lib.makeSearchPathOutput "dev" "include" audioLibraries}"
    export LIBRARY_PATH="${lib.makeLibraryPath audioLibraries}"
    exec uvx --from "voice-mode==${version}" voicemode "$@"
  '';
}
