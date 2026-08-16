# Troubleshooting

## macOS will not open the app

This build may not be notarized. In Finder: **right-click MacMedia → Open**.

If it is still blocked:

```bash
xattr -dr com.apple.quarantine /Applications/MacMedia.app
```

Then right-click → Open again. See the README [first-launch section](README.md#first-launch-on-macos).

## Video does not play

- Confirm the file opens in another libmpv-based player if you have one.
- Open **View → Statistics** and note decoder / error state.
- Try **Settings → Hardware Acceleration → Disabled**.
- Damaged or unsupported streams show *Unable to play this file* rather than a crash.

## Hardware decoding

- Auto uses mpv `hwdec=auto` (VideoToolbox when possible).
- Enabled forces `videotoolbox`.
- If the image is black but audio plays, disable hardware decoding and export diagnostics from Settings → Advanced.

## Audio

- Output uses macOS CoreAudio.
- Unplugging headphones should follow the default device. If it does not, pause and play again, or reopen the file.

## Subtitles

- Drag a `.srt` / `.ass` file onto a playing video, or **Subtitles → Load Subtitle**.
- A failed subtitle load should not stop the video.

## Network streams

- Only `http://` and `https://` URLs are opened through the engine.
- DRM / protected store content is not supported.
- Increase cache seconds in Settings → Network.

## External drives

The app is **not** sandboxed. If a file on an external disk cannot be read, check Finder permissions and that the volume is mounted.

## Performance

- 4K HEVC should use VideoToolbox on Apple Silicon.
- If frames drop, disable extra audio filters / equalizer, close the statistics overlay, and set hardware decoding to Auto or Enabled.
- Use a Release build (`Scripts/package-app.sh`), not `swift build -c debug`.
