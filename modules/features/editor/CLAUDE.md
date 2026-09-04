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

## kotlin-lsp is pinned to a build that expires

Kotlin support is JetBrains' `kotlin-lsp` (`_kotlin-lsp.nix`), not nixpkgs'
`kotlin-language-server` — the latter is unmaintained since Jan 2025 and its
embedded Kotlin 2.1 compiler cannot read stdlib metadata newer than 2.2, so
against a current project *every* top-level stdlib function reports
`Unresolved reference` while built-in classes still resolve. Helix already
defines a `kotlin-lsp` server, but its `kotlin` language still points at the old
one, so the language entry has to be overridden as well as the binary installed.

These are EAP builds and **stop running about thirty days after they are cut**
("This build of intellij-server has expired"), so the pin needs bumping roughly
monthly. Two traps in doing that:

- **The GitHub releases lag the CDN by enough to be useless** — the newest tag is
  routinely already expired. Take the build number from the VS Code marketplace
  extension instead (`extension/server/build.txt` inside the `linux-x64` vsix of
  `JetBrains.kotlin-server`), then fetch the standalone archive from the CDN path
  the release notes use. It is published there before the tag exists.
- Check `eap` and `date` in `idea/IntelliJServerApplicationInfo.xml`
  (`lib/language-server.main.jar`) to see how long a candidate build has left.

## kotlin-lsp needs a JDK *home* on PATH, and no JAVA_HOME

It runs its own analysis on the bundled JBR, but shells out for the Gradle/Maven
import — without a JDK it reports `no compatible JDKs found` and then resolves
nothing at all, with the file's diagnostics silently empty rather than failing.

Both halves of how that JDK is passed matter:

- **PATH, never JAVA_HOME.** A suffix leaves the machine's own java in front,
  which is what Indeed's Gradle plugin demands — it rejects the nixpkgs vendor
  and the import then yields an empty classpath without saying so.
- **`openjdk.home`, not `openjdk`.** `$out/bin` is a symlink into
  `lib/openjdk/bin`, so IntelliJ's probe walks up from `bin/java` to the package
  root, finds no `release` or `conf`, and discards it — `Checked Java paths: []`
  even though java is plainly on PATH.
