# Testing MacMedia

## Unit and engine tests

Command Line Tools do not always include `xctest`. Run:

```bash
Scripts/gen-test-media.sh
Scripts/run-tests.sh
```

`MacMediaTestRunner` covers:

- Time formatting
- File type detection including Unicode names
- Playlist / M3U
- Resume policy
- Keybindings and conflicts
- Preferences persistence
- Equalizer filter generation
- History
- Error mapping
- Headless libmpv open / seek / pause / missing and corrupt files
- Playlist stress (200 items)

## UI tests

There is no XCUITest host in a Command Line Tools-only setup. Coverage for the real app is:

```bash
Scripts/package-app.sh
open build/MacMedia.app
```

`Scripts/launch-smoke.sh` launches the app and checks the process.

## Media corpus

Documented in `TestMedia/README.md`. Generated locally with ffmpeg test patterns (not copyrighted):

- H.264 / HEVC / AAC / MP3 / FLAC / Opus / MKV / MP4 / SRT
- Unicode filenames
- Empty, random binary, and truncated files

Supply ProRes, HDR, or long 4K files locally if you need them. Do not download copyrighted media.
