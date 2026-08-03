_: {
  # The one nvtop this repo installs -- the bars poll it and `bundle-base` puts
  # it on PATH, from the same store path. A function of pkgs rather than a
  # module, since both callers only want the derivation.
  flake.lib.nvtop =
    pkgs:
    pkgs.nvtopPackages.full.override {
      # `full` already enables every backend; this argument has no default, and
      # answering it is what makes the NVIDIA one free and closure-free -- see
      # CLAUDE.md, "GPU metrics in the bar".
      cudatoolkit = null;
    };
}
