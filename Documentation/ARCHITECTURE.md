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

- libmpv calls run on a dedicated serial queue.
- `mpv_set_wakeup_callback` hops onto that queue and drains `mpv_wait_event(0)`.
- UI state is published on the main actor.
- Screenshots read the OpenGL framebuffer on the display thread (libmpv `screenshot-to-file` is unsafe with `vo=libmpv`).

## Rendering

Video is drawn with `vo=libmpv` into a `CAOpenGLLayer` via `mpv_render_context_render`. Hardware decoding uses mpv `hwdec` (`auto` / `videotoolbox` / `no`) and falls back to software if VideoToolbox fails.

## Safety defaults

- `load-scripts=no`
- `ytdl=no`
- Lua and JavaScript are disabled in the libmpv build
- The app is not App Sandboxed (Finder paths and HTTP(S) streams)

## Persistence

UserDefaults plus a small Codable JSON store under Application Support:

- window frame, volume, speed, settings
- history and resume positions (when enabled)
- optional remembered playlist

## License

GPL-3.0-or-later because the distribution includes GPL-configured FFmpeg and libmpv. See `LICENSE`, `NOTICE.md`, and `THIRD_PARTY_LICENSES.md`.
