# MacMedia

A fast, simple, and powerful native media player for macOS.

MacMedia follows a simple idea: **simple interface, powerful engine**. Open a file, watch it, and get out of the way. Advanced controls live in menus and Settings.

It is inspired by the usability philosophy of MPC-HC, not by its branding or artwork. Playback is handled by a bundled **libmpv** (FFmpeg, VideoToolbox, libass).

## Features

- Native macOS player window with auto-hiding controls
- Broad container/codec coverage through libmpv/FFmpeg (actual support is reported by the engine)
- Hardware decoding via VideoToolbox, with software fallback
- Playlist, history, and optional resume
- Subtitles (including sidecar files), audio tracks, playback speed, A-B loop
- Equalizer, color controls, screenshots, statistics overlay
- Keyboard and mouse customization
- HTTP/HTTPS streaming supported by the engine
- No accounts, ads, telemetry, or cloud dependency

## Requirements

- macOS 13 Ventura or newer
- Apple Silicon (arm64). This build is **not** Universal 2.

## Installation

1. Open `build/MacMedia.dmg`
2. Drag **MacMedia** into **Applications**
3. Launch it and open a media file

If Gatekeeper blocks the unsigned / development-signed build:

```bash
xattr -dr com.apple.quarantine /Applications/MacMedia.app
```

Then right-click the app and choose **Open**.

## Usage

- Drop a file on the window, use **File → Open**, or press ⌘O
- Space play/pause, arrows seek, up/down volume, F fullscreen, Esc exit fullscreen
- Right-click the video for a compact context menu
- Open **Settings** for hardware decoding, equalizer, shortcuts, and more

## Keyboard shortcuts

Defaults (all customizable in Settings → Keyboard):

| Key | Action |
| --- | --- |
| Space | Play/Pause |
| Left / Right | Seek |
| Shift+Left / Right | Larger seek |
| Up / Down | Volume |
| M | Mute |
| F | Fullscreen |
| Esc | Exit fullscreen |
| S | Screenshot |

## Supported media

MacMedia plays the formats supported by the bundled libmpv/FFmpeg build. Typical coverage includes MP4, MKV, MOV, WebM, MP3, AAC, FLAC, Opus, H.264, HEVC, and more. The player does **not** claim every format ever created. Unsupported or damaged files show a human-readable error instead of crashing.

## Known limitations

- arm64 only (Homebrew FFmpeg on this machine is arm64)
- OpenGL rendering path (`CAOpenGLLayer` + libmpv). Metal shaders are not compiled in this toolchain.
- Signed with an Apple Development identity when available; **not notarized** (no Developer ID Application certificate)
- No in-app updater
- Picture-in-picture is a compact always-on-top panel, not AVKit PiP

## License

GPL-3.0-or-later. Third-party notices: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)
