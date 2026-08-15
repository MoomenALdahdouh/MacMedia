# Troubleshooting

## Video does not play

- Confirm the file opens in another libmpv-based player if you have one.
- Open **View → Statistics** and note decoder / error state.
- Try **Settings → Hardware Acceleration → Disabled**.
- Damaged or unsupported streams show *Unable to play this file* rather than a crash. That message is expected for random/empty files.

## Hardware decoding issue

- Auto uses mpv `hwdec=auto` (VideoToolbox when possible).
- Enabled forces `videotoolbox`.
- If VideoToolbox fails, libmpv should fall back to software. If the image is black but audio plays, disable hardware decoding and file a diagnostics export from Settings → Advanced.

## Audio device issue

- macOS CoreAudio is the output backend.
- Unplugging headphones should move output to the default device. If it does not, pause and play again, or reopen the file.
- Settings → Audio delay is an mpv `audio-delay` offset, not a device picker replacement.

## Subtitle issue

- Drag a `.srt` / `.ass` file onto a playing video, or **Subtitles → Load Subtitle**.
- Failed subtitle loads must not stop video; if they do, that is a bug.
- Encoding is handled by libass/uchardet in the vendored build.

## Network stream issue

- Only `http://` and `https://` URLs are opened through the engine.
- DRM / protected store content is not supported and will not be bypassed.
- Increase cache seconds in Settings → Network.

## Missing codec / backend

The engine, not the UI, decides support. If libmpv reports an error, MacMedia shows it. There is no fake format list.

## Gatekeeper

Development-signed or ad-hoc builds are blocked until quarantine is removed:

```bash
xattr -dr com.apple.quarantine /Applications/MacMedia.app
```

Right-click → Open.

## External drive permissions

The app is **not** sandboxed. If a file on an external disk cannot be read, check Finder permissions and that the volume is mounted. History entries for moved files will fail with a missing-file error.

## Performance

- 4K60 HEVC should use VideoToolbox on Apple Silicon.
- If frames drop, disable extra audio filters / equalizer, close the statistics overlay, and set hardware decoding to Auto or Enabled.
- Do not run debug builds for playback measurement.
