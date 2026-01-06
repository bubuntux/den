{ channels, ... }:
_final: _prev: {
  inherit (channels.unstable) gemini-cli-bin;
}
