# MacMedia verification

Date: 2026-08-15  
Host: macOS 26.5.2, Apple M3, Swift 6.3.3, Command Line Tools (no Xcode.app)

```text
Project status:
BUILD: PASS
UNIT TESTS: PASS
UI TESTS: FAIL
MEDIA TESTS: PASS
STRESS TESTS: PASS
ARM64: PASS
X86_64: FAIL
UNIVERSAL: FAIL
DMG: PASS
APP LAUNCH: PASS
SIGNING: SIGNED
NOTARIZATION: NOT AVAILABLE
```

## Notes

- **BUILD:** `swift build -c debug` and `swift build -c release --product MacMedia` succeeded. `Scripts/package-app.sh` produced `build/MacMedia.app`.
- **UNIT / MEDIA / STRESS:** `MacMediaTestRunner` — 48 passed, 0 failed. Headless libmpv opened generated H.264, HEVC, MP3, MKV, Unicode filenames; missing/corrupt/empty files did not crash. Playlist stress (200 items) passed. Command Line Tools have no `xctest`, so tests are this executable (`Scripts/run-tests.sh`), not XCTest.
- **UI TESTS:** No XCUITest host without Xcode. Manual launch of the real `.app` succeeded (`APP LAUNCH: PASS`).
- **ARM64:** `Mach-O 64-bit executable arm64`. Homebrew FFmpeg on this machine is arm64-only.
- **X86_64 / UNIVERSAL:** Not built. Do not claim Universal 2.
- **DMG:** `build/MacMedia.dmg` (UDZO, contains app, Applications symlink, README, licenses).
- **SIGNING:** Apple Development: moomenaldahdouh@gmail.com (NS9S9TNXA7), Hardened Runtime, timestamp. This is **not** Developer ID. Gatekeeper will block copies moved to other Macs until quarantine is cleared / the app is notarized with a Developer ID certificate.
- **NOTARIZATION:** No Developer ID Application identity in the keychain.

## Artifacts

```text
build/MacMedia.app
build/MacMedia.dmg
```

## Formats actually tested

Generated locally (not copyrighted): H.264/AAC MP4, HEVC/AAC MP4, H.264 MKV, MP3, FLAC, Opus, MKV+SRT, multi-audio MKV, Unicode names, empty/corrupt/random files.

Not tested here: ProRes, HDR10, commercial 4K60, live HTTP streams. Support for those depends on the bundled libmpv/FFmpeg build, which includes VideoToolbox, x264, x265, dav1d, libvpx, and libass.
