# Testing MacMedia

## Unit tests

Command Line Tools on this machine do not include `xctest`. Run:

```bash
Scripts/run-tests.sh
```

The `MacMediaTestRunner` executable covers:

- Time formatting
- File type detection including Unicode names
- Playlist / M3U
- Resume policy
- Keybindings and conflicts
- Preferences persistence
- Equalizer filter generation
- History
- Error mapping

## Integration tests

`EngineIntegrationTests` start a **headless** libmpv (`vo=null`, `ao=null`) and:

- Open generated H.264
- Seek, pause, volume, speed
- Missing file → error, no crash
- Corrupt / empty files
- Hardware decoding toggles

Generate fixtures first (original synthetic media, not copyrighted downloads):

```bash
Scripts/gen-test-media.sh
```

## Stress tests

Rapid playlist next/previous on 200 items.

Additional manual / scripted stress (open the `.app`):

- Rapid seek and play/pause
- Enter/exit fullscreen repeatedly
- Delete the current file while playing
- Toggle hardware decoding during playback

## UI tests

There is no Xcode XCUITest host on the Command Line Tools toolchain. Coverage for the real app is:

```bash
Scripts/package-app.sh
open build/MacMedia.app
```

plus `Scripts/launch-smoke.sh` which launches the app and checks the process.

## Media test corpus

Documented in `TestMedia/README.md`. Generated coverage:

- H.264 / HEVC / AAC / MP3 / FLAC / Opus / MKV / MP4 / SRT
- Unicode filenames
- Empty, random binary, and truncated files

Not generated here (encoders or sample assets unavailable / not redistributable):

- ProRes
- HDR10 mastering display metadata
- Commercial 4K60 feature files

Supply those locally if you need them. Do not download copyrighted media.
