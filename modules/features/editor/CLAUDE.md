# Editor

## kotlin-lsp is pinned to a build that expires

Kotlin support is JetBrains' `kotlin-lsp` (`_kotlin-lsp.nix`), not nixpkgs'
`kotlin-language-server` — the latter is unmaintained since Jan 2025 and its
embedded Kotlin 2.1 compiler cannot read stdlib metadata newer than 2.2, so
against a current project *every* top-level stdlib function reports
`Unresolved reference` while built-in classes still resolve.

These are EAP builds and **stop running about thirty days after they are cut**
("This build of intellij-server has expired") — and an expired build still
*builds*, so nothing goes red. The `kotlin-lsp-bump` action does the bump on
`update-flake.yml`'s cron; when it fails, that step is marked failed and the
flake update goes ahead without it, so a pin that stops moving means the step
below has broken. Two traps it encodes, for when it needs fixing:

- **The GitHub releases lag the CDN by enough to be useless** — the newest tag is
  routinely already expired. Take the build number from the VS Code marketplace
  extension instead (`extension/server/build.txt` inside the `linux-x64` vsix of
  `JetBrains.kotlin-server`), then fetch the standalone archive from the
  `download.jetbrains.com` path the release notes use (`download-cdn` 404s). It
  is published there before the tag exists.
- Check `eap` and `date` in `idea/IntelliJServerApplicationInfo.xml`
  (`lib/language-server.main.jar`) to see how long a candidate build has left.

## kotlin-lsp needs a JDK *home* on PATH, and its Gradle JDK pinned

It runs its own analysis on the bundled JBR, but shells out for the Gradle/Maven
import — without a JDK it reports `no compatible JDKs found` and then resolves
nothing at all, with the file's diagnostics silently empty rather than failing.

Three parts to how that JDK is passed, each failing differently:

- **A JDK on PATH, JAVA_HOME left alone.** The wrapper suffixes one on so there
  is always a JDK to find; JAVA_HOME stays whatever the user set, naming the JDK
  the project is really built with — which is what the next point pins to.
- **PATH order decides nothing, so pin the system property.**
  `GradleToolingApiHelper.findTheMostCompatibleJdk` takes every JDK
  `JavaHomeFinder` turns up, drops the ones the project's Gradle cannot run,
  sorts by version descending and keeps the first; JAVA_HOME is consulted only
  if that list comes out empty. So the JDK you build with loses to any newer one
  on the box — including the `openjdk` suffixed onto PATH, whose `java.vendor`
  is `N/A`. Vendor-checking Gradle plugins (Indeed's, for one) reject that, and
  a failed import is invisible from the editor: the server still answers, only
  with an empty workspace model, so references and go-to-definition come back
  empty. `-Dcom.jetbrains.ls.imports.gradle.java.home` is the one input checked
  ahead of the version sort, so the wrapper sets it from JAVA_HOME through
  `IJ_JAVA_OPTIONS`, which the native launcher appends to its vmoptions.
- **`openjdk.home`, not `openjdk`.** `$out/bin` is a symlink into
  `lib/openjdk/bin`, so IntelliJ's probe walks up from `bin/java` to the package
  root, finds no `release` or `conf`, and discards it — `Checked Java paths: []`
  even though java is plainly on PATH.
