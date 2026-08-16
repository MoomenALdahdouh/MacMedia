# Building MacMedia

The installed `.app` does **not** need Homebrew, Python, Node, or a network connection. Those tools are only for compiling.

## Requirements

- macOS 13 or later, Apple Silicon (arm64)
- Apple Command Line Tools or Xcode (Swift Package Manager)
- Homebrew packages used at **build time**:

```bash
brew install meson ninja pkgconf ffmpeg libass libplacebo little-cms2 uchardet zimg libarchive jpeg-turbo
```

## Vendor libmpv

```bash
Scripts/vendor-libs.sh
```

This clones [mpv 0.41.0](https://github.com/mpv-player/mpv), builds a **minimal libmpv** (no Lua, no JavaScript, no vapoursynth, no mpv CLI), and rewrites dylib paths. Runtime libraries are copied into `MacMedia.app/Contents/Frameworks` with `@rpath` install names.

## Build

```bash
swift build -c debug --product MacMedia
swift build -c release --product MacMedia
```

## Test

```bash
Scripts/gen-test-media.sh
Scripts/run-tests.sh
```

See [TESTING.md](TESTING.md).

## Package

```bash
Scripts/package-app.sh
Scripts/package-dmg.sh
```

Outputs:

```text
build/MacMedia.app
build/MacMedia.dmg
```

Install locally:

```bash
Scripts/install.sh
```

Signing uses `CODESIGN_IDENTITY` if set, otherwise the first Developer ID or Apple Development identity in the keychain, otherwise ad-hoc. Notarization is not performed unless you have a Developer ID Application certificate and run `notarytool` yourself (see [RELEASE.md](RELEASE.md)).
