# MacMedia Architecture

MacMedia is a native macOS media player. The user-facing interface stays simple; playback is delegated to a bundled libmpv.

## Layers

```
UI (AppKit window, SwiftUI panels, native menus)
  → Application (PlaybackCoordinator, playlist, history, preferences, keybindings)
    → Media (MediaPlayerEngine protocol, MpvEngine)
      → libmpv + FFmpeg + VideoToolbox + libass
```

Playback logic does not live in SwiftUI views. Views observe `PlaybackCoordinator` and send user intents. `MpvEngine` is the only type that talks to libmpv.

## Threading

- libmpv calls run on a dedicated serial `player` queue.
- `mpv_set_wakeup_callback` hops onto that queue and drains `mpv_wait_event(0)`.
- UI state is published on the main actor.
- Filesystem scans, M3U parsing, and history IO use cooperative Swift concurrency off the main thread.

## Rendering

Video is drawn with `vo=libmpv` into a `CAOpenGLLayer` via `mpv_render_context_render`. This is the proven embedding path on macOS (IINA / libmpv examples). Custom Metal shaders are not used because this environment has Command Line Tools only (no `metal` compiler).

Hardware decoding uses mpv `hwdec` (`auto` / `videotoolbox` / `no`) and falls back to software if VideoToolbox fails.

## Safety defaults

- `load-scripts=no`
- `ytdl=no`
- Lua and JavaScript are disabled in the libmpv build
- The app is not App Sandboxed (Finder / arbitrary paths / HTTP(S) streams)

## Persistence

UserDefaults + a small Codable JSON store under Application Support:

- window frame, volume, speed, settings
- history and resume positions (when enabled)
- optional remembered playlist

Decoder / renderer state is never persisted.

## Updates

`UpdateChecking` is a no-op protocol so an updater can be added later without touching playback.

## License

The application is GPL-3.0-or-later because it bundles GPL-configured FFmpeg and libmpv. See `THIRD_PARTY_LICENSES.md`.
