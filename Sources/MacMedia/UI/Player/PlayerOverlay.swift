import SwiftUI
import MacMediaCore

struct PlayerTopBar: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(coordinator.state.title.isEmpty ? "MacMedia" : coordinator.state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            chromeButton("list.bullet", selected: coordinator.showPlaylist, help: "Playlist") {
                coordinator.showPlaylist.toggle()
            }
            chromeButton("info.circle", selected: coordinator.showStats, help: "Statistics") {
                coordinator.showStats.toggle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.55))
    }

    private var statusLine: String {
        switch coordinator.state.status {
        case .idle: return "Ready"
        case .loading: return "Loading…"
        case .playing: return playingMeta
        case .paused: return "Paused · \(playingMeta)"
        case .buffering: return "Buffering…"
        case .seeking: return "Seeking…"
        case .ended: return "Ended"
        case .error: return "Unable to play"
        }
    }

    private var playingMeta: String {
        let stats = coordinator.state.statistics
        var parts: [String] = []
        if stats.width > 0 { parts.append("\(stats.width)×\(stats.height)") }
        if !stats.codec.isEmpty { parts.append(stats.codec.uppercased()) }
        if !stats.audioCodec.isEmpty { parts.append(stats.audioCodec.uppercased()) }
        if coordinator.state.speed != 1 { parts.append(String(format: "%.2gx", coordinator.state.speed)) }
        return parts.isEmpty ? "Playing" : parts.joined(separator: " · ")
    }

    private func chromeButton(_ systemName: String, selected: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.accentColor : Color.white.opacity(0.92))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct PlayerCenterOverlay: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        Group {
            if coordinator.state.status == .idle && coordinator.state.url == nil {
                emptyState
            } else if coordinator.state.status == .loading {
                loadingState
            } else if coordinator.state.status == .buffering {
                bufferingState
            } else if coordinator.state.status == .error {
                errorState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Drop a video here")
                .font(.title2.weight(.semibold))
            Text("Or open a file. MacMedia stays on your Mac — nothing is uploaded.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Open File…") { AppDelegate.shared?.openFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder…") { AppDelegate.shared?.openFolder() }
                Button("Open URL…") { AppDelegate.shared?.openURL() }
            }
            .controlSize(.large)
            if !coordinator.history.all().isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(coordinator.history.all().prefix(5)) { entry in
                        Button {
                            coordinator.open(urls: [entry.url])
                        } label: {
                            HStack {
                                Text(entry.title).lineLimit(1)
                                Spacer()
                                Text(TimeFormatting.clock(entry.position, includeHours: true))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: 360)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.yellow)
            Text(coordinator.state.error?.title ?? "Unable to play this file.")
                .font(.headline)
            Text(coordinator.state.error?.userMessage ?? coordinator.state.errorDetail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            HStack(spacing: 10) {
                Button("Open Another File") { AppDelegate.shared?.openFile() }
                    .keyboardShortcut(.defaultAction)
                Button("Show Playlist") { coordinator.showPlaylist = true }
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var loadingState: some View {
        ProgressView("Loading…")
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var bufferingState: some View {
        ProgressView("Buffering…")
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PlayerOSD: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
}

struct PlaylistSidebar: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        PlaylistView(coordinator: coordinator)
            .frame(width: 300)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(Rectangle().frame(width: 1).foregroundStyle(Color.primary.opacity(0.08)), alignment: .leading)
    }
}

struct ControlBarView: View {
    @ObservedObject var coordinator: PlaybackCoordinator
    var onSettings: () -> Void
    var onFullscreen: () -> Void
    var onPictureInPicture: () -> Void
    var onSpeedMenu: () -> Void
    var onAudioMenu: () -> Void
    var onSubtitleMenu: () -> Void

    private var duration: Double { coordinator.state.duration }
    private var hasHours: Bool { coordinator.state.duration >= 3600 }

    var body: some View {
        VStack(spacing: 8) {
            seekRow
            buttonsRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playback controls")
    }

    private var seekRow: some View {
        HStack(spacing: 10) {
            Text(TimeFormatting.clock(coordinator.state.position, includeHours: hasHours))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 62, alignment: .trailing)
            SeekBar(
                value: coordinator.state.position,
                duration: duration,
                chapters: coordinator.state.chapters,
                onSeek: { time, dragging in
                    coordinator.engine.seek(
                        to: time,
                        mode: dragging ? .fast : .accurate
                    )
                }
            )
            Text(TimeFormatting.clock(coordinator.state.duration, includeHours: hasHours))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 62, alignment: .leading)
        }
    }

    private var buttonsRow: some View {
        HStack(spacing: 6) {
            muteButton
            VolumeBar(value: coordinator.state.volume) { volume in
                coordinator.engine.setVolume(volume)
                if coordinator.state.muted {
                    coordinator.engine.setMuted(false)
                }
            }

            Spacer(minLength: 8)

            iconButton("backward.end.fill", "Previous") { coordinator.playPrevious() }
            iconButton("gobackward.10", "Seek backward 10 seconds") { coordinator.skipBackward() }
            playButton
            iconButton("goforward.10", "Seek forward 10 seconds") { coordinator.skipForward() }
            iconButton("forward.end.fill", "Next") { coordinator.playNext() }
            iconButton("stop.fill", "Stop") { coordinator.stopPlayback() }

            Spacer(minLength: 8)

            menuButton(speedLabel, help: "Playback speed", action: onSpeedMenu)
            iconButton("waveform", "Audio track", action: onAudioMenu)
            iconButton("captions.bubble", "Subtitles", action: onSubtitleMenu)
            iconButton("camera", "Screenshot") { coordinator.takeScreenshot() }
            iconButton("list.bullet", "Playlist", selected: coordinator.showPlaylist) {
                coordinator.showPlaylist.toggle()
            }
            iconButton("pip", "Picture in Picture", action: onPictureInPicture)
            iconButton("arrow.up.left.and.arrow.down.right", "Fullscreen", action: onFullscreen)
            iconButton("gearshape", "Settings", action: onSettings)
        }
        .foregroundStyle(.white)
    }

    private var playButton: some View {
        Button(action: {
            coordinator.togglePlayPause { AppDelegate.shared?.openFile() }
        }) {
            Image(systemName: coordinator.state.playPauseSystemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(coordinator.state.playPauseAccessibilityLabel)
        .accessibilityLabel(coordinator.state.playPauseAccessibilityLabel)
    }

    private var muteButton: some View {
        Button(action: { coordinator.engine.setMuted(!coordinator.state.muted) }) {
            Image(systemName: volumeIcon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 28)
        }
        .buttonStyle(.plain)
        .help(coordinator.state.muted ? "Unmute" : "Mute")
        .accessibilityLabel(coordinator.state.muted ? "Unmute" : "Mute")
    }

    private var volumeIcon: String {
        if coordinator.state.muted || coordinator.state.volume <= 0 { return "speaker.slash.fill" }
        if coordinator.state.volume < 40 { return "speaker.wave.1.fill" }
        if coordinator.state.volume < 90 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var speedLabel: String {
        coordinator.state.speed == 1 ? "1×" : String(format: "%.2g×", coordinator.state.speed)
    }

    private func menuButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(minWidth: 36)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func iconButton(_ systemName: String, _ help: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.accentColor : Color.white.opacity(0.95))
                .frame(width: 26, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct SeekBar: View {
    let value: Double
    let duration: Double
    let chapters: [ChapterMarker]
    let onSeek: (Double, Bool) -> Void
    @State private var dragValue: Double?

    var body: some View {
        GeometryReader { geo in
            let displayed = dragValue ?? value
            let progress = duration > 0 ? min(1, max(0, displayed / duration)) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 5)
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(6, geo.size.width * progress), height: 5)
                ForEach(chapters) { chapter in
                    let x = duration > 0 ? geo.size.width * (chapter.time / duration) : 0
                    Rectangle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 1, height: 8)
                        .offset(x: x)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: 11, height: 11)
                    .offset(x: max(0, geo.size.width * progress - 5.5))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard duration > 0.25 else { return }
                        let ratio = min(1, max(0, drag.location.x / max(geo.size.width, 1)))
                        let time = ratio * duration
                        dragValue = time
                        onSeek(time, true)
                    }
                    .onEnded { drag in
                        guard duration > 0.25 else { return }
                        let ratio = min(1, max(0, drag.location.x / max(geo.size.width, 1)))
                        let time = ratio * duration
                        onSeek(time, false)
                        dragValue = nil
                    }
            )
        }
        .frame(height: 18)
        .accessibilityLabel("Seek")
        .accessibilityValue(TimeFormatting.clock(value, includeHours: duration >= 3600))
    }
}

struct VolumeBar: View {
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let progress = min(1, max(0, value / 150))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 5)
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(4, geo.size.width * progress), height: 5)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let ratio = min(1, max(0, drag.location.x / max(geo.size.width, 1)))
                    onChange(ratio * 150)
                }
            )
        }
        .frame(width: 92, height: 18)
        .help("Volume")
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(value.rounded()))")
    }
}

struct CleanControlHUD: View {
    @ObservedObject var coordinator: PlaybackCoordinator
    var onPictureInPicture: () -> Void
    var onMore: () -> Void

    private var duration: Double { coordinator.state.duration }
    private var hasHours: Bool { coordinator.state.duration >= 3600 }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button(action: { coordinator.engine.setMuted(!coordinator.state.muted) }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(coordinator.state.muted ? "Unmute" : "Mute")

                VolumeBar(value: coordinator.state.volume) { volume in
                    coordinator.engine.setVolume(volume)
                    if coordinator.state.muted {
                        coordinator.engine.setMuted(false)
                    }
                }
                .frame(width: 72)

                Spacer(minLength: 8)

                Button(action: { coordinator.skipBackward() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Seek backward")

                Button(action: { coordinator.togglePlayPause { AppDelegate.shared?.openFile() } }) {
                    Image(systemName: coordinator.state.playPauseSystemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
                .help(coordinator.state.playPauseAccessibilityLabel)

                Button(action: { coordinator.skipForward() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Seek forward")

                Spacer(minLength: 8)

                Button(action: onPictureInPicture) {
                    Image(systemName: "pip")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Picture in Picture")

                Button(action: onMore) {
                    Image(systemName: "chevron.forward.2")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("More")
            }

            HStack(spacing: 8) {
                Text(TimeFormatting.clock(coordinator.state.position, includeHours: hasHours))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 48, alignment: .leading)
                SeekBar(
                    value: coordinator.state.position,
                    duration: duration,
                    chapters: coordinator.state.chapters,
                    onSeek: { time, dragging in
                        coordinator.engine.seek(to: time, mode: dragging ? .fast : .accurate)
                    }
                )
                Text(TimeFormatting.clock(coordinator.state.duration, includeHours: hasHours))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 460)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 6)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playback controls")
    }

    private var volumeIcon: String {
        if coordinator.state.muted || coordinator.state.volume <= 0 { return "speaker.slash.fill" }
        if coordinator.state.volume < 40 { return "speaker.wave.1.fill" }
        if coordinator.state.volume < 90 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct StatsOverlay: View {
    let state: PlaybackState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Decoder: \(blank(state.statistics.decoder))")
            Text("Renderer: \(blank(state.statistics.renderer, fallback: "OpenGL / libmpv"))")
            Text("Hardware Decode: \(blank(state.statistics.hardwareDecoding))")
            Text("Resolution: \(state.statistics.width)×\(state.statistics.height)")
            Text(String(format: "FPS: %.2f", state.statistics.fps))
            Text("Dropped Frames: \(state.statistics.droppedFrames)")
            Text("Video Bitrate: \(bitrate(state.statistics.videoBitrate))")
            Text("Audio: \(blank(state.statistics.audioCodec)) \(state.statistics.audioSampleRate) Hz")
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(10)
        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(.white)
        .accessibilityLabel("Playback statistics")
    }

    private func blank(_ value: String, fallback: String = "—") -> String {
        value.isEmpty ? fallback : value
    }

    private func bitrate(_ value: Int) -> String {
        guard value > 0 else { return "—" }
        if value > 1_000_000 { return String(format: "%.2f Mbps", Double(value) / 1_000_000) }
        return "\(value / 1000) kbps"
    }
}
