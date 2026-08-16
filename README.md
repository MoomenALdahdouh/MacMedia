# MacMedia

A fast, simple native media player for macOS (Apple Silicon).

Open a file, watch it, and get out of the way. No accounts, ads, telemetry, or cloud. Playback is powered by a bundled [libmpv](https://mpv.io) engine (FFmpeg, VideoToolbox, libass).

[Download for macOS](https://github.com/MoomenALdahdouh/MacMedia/releases/latest) · [How to open](#first-launch-on-macos) · [Build from source](BUILD.md)

**Requires:** macOS 13 Ventura or later, Apple Silicon (M1/M2/M3/M4). This release is arm64 only.

## Install

1. Download **MacMedia.dmg** from the [latest release](https://github.com/MoomenALdahdouh/MacMedia/releases/latest).
2. Open the disk image and drag **MacMedia** into **Applications**.
3. Eject the disk image, then launch MacMedia from Applications.

### First launch on macOS

macOS Gatekeeper may block the first open because this build is not notarized with an Apple Developer ID. That is expected.

**Easiest:** in Finder, **right-click MacMedia → Open**, then click **Open**.

If macOS still refuses:

```bash
xattr -dr com.apple.quarantine /Applications/MacMedia.app
```

Then right-click → **Open** again.

## Usage

- Drop a file on the window, choose **File → Open**, or press ⌘O
- Space play/pause, arrow keys seek, ↑/↓ volume, F fullscreen, Esc exit fullscreen
- Right-click the video for a compact menu
- **Settings** for hardware decoding, equalizer, shortcuts, and more
- **File → New Window** to play more than one file at once

### Keyboard shortcuts

Defaults (customizable in Settings → Keyboard):

| Key | Action |
| --- | --- |
| Space | Play / Pause / Replay |
| Left / Right | Seek |
| Shift+Left / Right | Larger seek |
| Up / Down | Volume |
| M | Mute |
| F | Fullscreen |
| Esc | Exit fullscreen |
| S | Screenshot (saved to Pictures/MacMedia) |

## Features

- Native macOS window with auto-hiding controls and an optional compact (Clean) view
- Broad format coverage through libmpv/FFmpeg (MP4, MKV, MOV, WebM, MP3, AAC, FLAC, Opus, H.264, HEVC, and more)
- Hardware decoding via VideoToolbox, with software fallback
- Playlist, history, and optional resume
- Subtitles (including sidecar `.srt` / `.ass`), audio tracks, speed, A-B loop
- Equalizer, color controls, screenshots, statistics overlay
- Picture-in-Picture as a compact always-on-top window
- HTTP/HTTPS streaming supported by the engine

Unsupported or damaged files show an error instead of crashing. MacMedia does not claim every format ever created.

## Build from source

See [BUILD.md](BUILD.md). Runtime libraries are bundled inside the `.app`; Homebrew is only needed when compiling.

## License

[GPL-3.0-or-later](LICENSE). Third-party notices: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) and [NOTICE.md](NOTICE.md).
