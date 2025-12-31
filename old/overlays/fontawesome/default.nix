{ channels, ... }:
final: prev: {
  inherit (channels.unstable) font-awesome;
}
