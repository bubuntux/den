{ pkgs, lib, ... }:
let
  # Define the libraries you want nix-ld to be aware of.
  # These are examples; adjust them based on your needs.
  nixLdLibs = with pkgs; [
    SDL
    SDL2
    SDL2_image
    SDL2_mixer
    SDL2_ttf
    SDL_image
    SDL_mixer
    SDL_ttf
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    bzip2
    cairo
    cups
    curlWithGnuTls
    dbus
    dbus-glib
    desktop-file-utils
    e2fsprogs
    expat
    flac
    fontconfig
    freeglut
    freetype
    fribidi
    fuse
    fuse3
    gdk-pixbuf
    glew110
    glib
    gmp
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-ugly
    gst_all_1.gstreamer
    gtk2
    harfbuzz
    icu
    keyutils.lib
    libGL
    libGLU
    libappindicator-gtk2
    libcaca
    libcanberra
    libcap
    libclang.lib
    libdbusmenu
    libdrm
    libgcrypt
    libgpg-error
    libidn
    libjack2
    libjpeg
    libmikmod
    libogg
    libpng12
    libpulseaudio
    librsvg
    libsamplerate
    libthai
    libtheora
    libtiff
    libudev0-shim
    libusb1
    libuuid
    libvdpau
    libvorbis
    libvpx
    libxcrypt-legacy
    libxkbcommon
    libxml2
    mesa
    nspr
    nss
    openssl
    p11-kit
    pango
    pixman
    python3
    speex
    stdenv.cc.cc
    tbb
    udev
    vulkan-loader
    wayland
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXft
    xorg.libXi
    xorg.libXinerama
    xorg.libXmu
    xorg.libXrandr
    xorg.libXrender
    xorg.libXt
    xorg.libXtst
    xorg.libXxf86vm
    xorg.libpciaccess
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    xorg.xkeyboardconfig
    xz
    zlib
  ];

  # Create the library path string
  nixLdLibraryPath = lib.makeLibraryPath nixLdLibs;

  # Get the path to the nix-ld provided dynamic linker
  # This assumes glibc by default. Adjust if your system/target programs use a different libc.
  nixLd = pkgs.stdenv.cc.bintools.dynamicLinker;
  # Or more robustly find the linker provided by nix-ld's cc
  # A common path might be from stdenv.cc:
  # lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker"
  # However, for non-NixOS, you'd typically point to the Nix-provided linker.
  # A simpler way if pkgs.nix-ld includes a readily usable linker path variable:
  # NIX_LD = "${pkgs.nix-ld}/lib/ld-linux-x86-64.so.2"; # Example, verify path
  # For general use with Nix-provided glibc:
  # nixLdPath = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
  nixLdPath = "${pkgs.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2";
in

{

  programs.vscode.enable = true;

  home = {
    sessionVariables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      GOPATH = "$HOME/.go";
      # NIX_LD_LIBRARY_PATH = nixLdLibraryPath;
      # NIX_LD = nixLdPath;
    };
    sessionPath = [
      "$HOME/.cargo/bin"
      "$HOME/.go/bin"
    ];
    packages = with pkgs; [
      pkg-config
      openssl

      # devenv

      podman
      podman-compose

      # fenix setup?  https://github.com/nix-community/fenix
      libgcc
      gcc
      rustup
    ];
  };
}
