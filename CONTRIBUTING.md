# Contributing to MacMedia

Thanks for helping. Please keep the player simple: native macOS UI, no accounts, no ads, no telemetry.

## Development setup

1. macOS 13+ on Apple Silicon
2. Command Line Tools or Xcode
3. Homebrew packages listed in [BUILD.md](BUILD.md)
4. `Scripts/vendor-libs.sh`
5. `swift build -c debug --product MacMedia`

Package a runnable app with `Scripts/package-app.sh`. Copy `build/MacMedia.app` to `/Applications` (or run `Scripts/install.sh`) before testing Finder “Open With”.

## Tests

```bash
Scripts/gen-test-media.sh
Scripts/run-tests.sh
```

Do not add copyrighted media to the repo.

## Pull requests

- Keep diffs focused. Do not mix refactors with bug fixes.
- Match the existing AppKit + SwiftUI style.
- Playback belongs in `PlaybackCoordinator` / `MpvEngine`, not in views.
- Do not add crashy libmpv calls on the main thread (see screenshot capture in `VideoView`).
