# Editor

## Helix comes from the flake input, not nixpkgs

nixpkgs packages the last tagged Helix release, and upstream cuts releases
rarely enough that it sits many hundreds of commits behind master. So
`programs.helix.package` is built from the `helix` flake input, lockfile-pinned
and bumped by `nix flake update helix`.

That choice carries a trap worth knowing before touching the package line.

## Why the grammar list is filtered

Helix's own flake resolves every tree-sitter grammar with `builtins.fetchTree`
at **evaluation** time, passing a rev but no `narHash`. A hash-less eval fetch
is not substitutable: Nix has to reach the forge to compute the derivation, so
neither cache.nixos.org nor helix.cachix.org nor den.cachix.org can stand in for
it. Every build on a cold machine clones *each* grammar repo, and one
unreachable forge fails the whole thing.

Most grammars live on GitHub, but a couple of dozen live on codeberg, gitlab and
sr.ht, and those are the ones that have actually broken CI — rate limits, 503s,
and one account deleted outright, taking its grammar with it. `includeGrammarIf`
therefore keeps only the GitHub-hosted grammars. The cost is syntax highlighting
for the dropped languages; check the current list before assuming one you need
is still there.

Two consequences to keep in mind:

- **Any** override changes the derivation, so helix.cachix.org no longer
  matches and CI compiles Helix from source once per input bump. den.cachix.org
  carries it from there. This is not specific to `includeGrammarIf` — it is the
  price of deviating from upstream's expression at all, so a narrower filter
  would not buy the cache back.
- CI caches `~/.cache/nix` for the same reason. Warm, it answers the remaining
  fetches without the network; that is the only thing standing between a GitHub
  outage and a red build. Cache the whole directory, not one subdirectory of
  it: GitHub-hosted grammars land in `tarball-cache-v2`, and `gitv3` only ever
  held the non-GitHub ones the filter above now drops.

Upstream intends to replace per-grammar fetching with a single tree-house clone
([#12831](https://github.com/helix-editor/helix/pull/12831)). When that lands,
both the filter and the cache step can go.
