# Building MacMedia

## Requirements

- macOS 13+
- Apple Command Line Tools or Xcode (this project builds with Swift Package Manager)
- Homebrew packages used at **build time only**: meson, ninja, pkgconf, ffmpeg, libass, libplacebo, little-cms2, uchardet, zimg, libarchive, jpeg-turbo
- The installed `.app` does **not** require Homebrew, Python, Node, or a network connection

## Dependencies

Runtime libraries are vendored into `MacMedia.app/Contents/Frameworks` with `@rpath` install names.

```bash
Scripts/vendor-libs.sh
```

This clones mpv 0.41.0, builds a **minimal libmpv** (no lua, no javascript, no vapoursynth, no mpv CLI), and rewrites dylib paths.

## Build commands

```bash
swift build -c debug
swift build -c release --product MacMedia
```

## Test commands

```bash
Scripts/gen-test-media.sh
Scripts/run-tests.sh
```

## Release / packaging commands

```bash
Scripts/package-app.sh
Scripts/package-dmg.sh
```

Outputs:

```text
build/MacMedia.app
build/MacMedia.dmg
```

Optional:

```bash
CODESIGN_IDENTITY="Apple Development: Name (TEAMID)" Scripts/package-app.sh
```

If no Developer ID Application identity is present, the script signs with Apple Development or ad-hoc. Notarization is not performed.

## Clean checkout

From a clean tree:

1. Install the Homebrew build packages listed above
2. `Scripts/vendor-libs.sh`
3. `swift test`
4. `Scripts/package-app.sh && Scripts/package-dmg.sh`
