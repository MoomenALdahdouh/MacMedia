import AppKit
import SwiftUI
import MacMediaCore

final class SettingsWindowController: NSWindowController {
    init(coordinator: PlaybackCoordinator) {
        let hosting = NSHostingController(rootView: SettingsView(coordinator: coordinator))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 520))
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }
}

struct SettingsView: View {
    @ObservedObject var coordinator: PlaybackCoordinator
    @State private var section: SettingsSection = .general
    @State private var prefs: AppPreferences = PreferencesManager.shared.current
    @State private var conflict: KeybindingConflict?

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { item in
                Text(item.title).tag(item)
            }
            .frame(minWidth: 180)
        } detail: {
            Form {
                switch section {
                case .general: general
                case .playback: playback
                case .video: video
                case .audio: audio
                case .subtitles: subtitles
                case .interface: interface
                case .keyboard: keyboard
                case .mouse: mouse
                case .playlist: playlist
                case .history: history
                case .network: network
                case .hardware: hardware
                case .advanced: advanced
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .onAppear { prefs = coordinator.preferences.current }
        .onChange(of: prefs) { new in
            coordinator.preferences.replace(new)
            applyLive(new)
        }
        .alert("Shortcut already assigned", isPresented: Binding(get: { conflict != nil }, set: { if !$0 { conflict = nil } })) {
            Button("Keep Existing", role: .cancel) { conflict = nil }
            Button("Reassign") {
                if let conflict {
                    coordinator.keybindings.forceSet(conflict.chord, for: conflict.command)
                }
                self.conflict = nil
            }
        } message: {
            if let conflict {
                Text("Shortcut already assigned to: \(conflict.occupant.title)")
            }
        }
        .frame(minWidth: 520, minHeight: 400)
    }

    private var general: some View {
        Section("General") {
            Toggle("Remember playback position", isOn: $prefs.rememberPlaybackPosition)
            Toggle("Ask before resuming", isOn: $prefs.resumePrompt)
            Toggle("Auto play next", isOn: $prefs.autoPlayNext)
            Toggle("Discover neighboring files in the same folder", isOn: $prefs.playSiblingsInFolder)
        }
    }

    private var playback: some View {
        Section("Playback") {
            Picker("Seek mode", selection: $prefs.seekMode) {
                Text("Accurate").tag(SeekMode.accurate)
                Text("Fast").tag(SeekMode.fast)
            }
            Slider(value: $prefs.shortSeek, in: 1...30, step: 1) { Text("Short seek: \(Int(prefs.shortSeek))s") }
            Slider(value: $prefs.longSeek, in: 10...180, step: 5) { Text("Large seek: \(Int(prefs.longSeek))s") }
            Toggle("Preserve audio pitch", isOn: $prefs.audioPitchCorrection)
            Picker("Repeat", selection: $prefs.repeatMode) {
                Text("Off").tag(RepeatMode.off)
                Text("One").tag(RepeatMode.one)
                Text("All").tag(RepeatMode.all)
            }
            Toggle("Shuffle", isOn: $prefs.shuffle)
        }
    }

    private var video: some View {
        Section("Video") {
            Picker("Aspect ratio", selection: $coordinator.geometry.aspect) {
                ForEach(AspectMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Slider(value: $coordinator.geometry.zoom, in: 0.5...2.0) { Text("Zoom \(Int(coordinator.geometry.zoom * 100))%") }
            Slider(value: $coordinator.color.brightness, in: -100...100) { Text("Brightness") }
            Slider(value: $coordinator.color.contrast, in: -100...100) { Text("Contrast") }
            Slider(value: $coordinator.color.saturation, in: -100...100) { Text("Saturation") }
            Slider(value: $coordinator.color.hue, in: -100...100) { Text("Hue") }
            Slider(value: $coordinator.color.gamma, in: -100...100) { Text("Gamma") }
            Toggle("Deinterlace", isOn: $prefs.deinterlace)
            Button("Reset video adjustments") { coordinator.resetVideo() }
        }
        .onChange(of: coordinator.geometry) { new in coordinator.engine.setGeometry(new) }
        .onChange(of: coordinator.color) { new in coordinator.engine.setColor(new) }
    }

    private var audio: some View {
        Section("Audio") {
            Toggle("Volume normalization", isOn: $prefs.volumeNormalization)
            Toggle("ReplayGain", isOn: $prefs.replayGain)
            Slider(value: $coordinator.audioDelay, in: -5...5) { Text("Audio delay") }
            Text("Equalizer").font(.headline)
            Picker("Preset", selection: $coordinator.equalizerPreset) {
                ForEach(EqualizerPreset.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .onChange(of: coordinator.equalizerPreset) { preset in
                coordinator.applyPreset(preset)
            }
            Slider(value: $coordinator.equalizer.preamp, in: -12...12) { Text("Preamp") }
            ForEach($coordinator.equalizer.bands) { $band in
                Slider(value: $band.gain, in: -12...12) { Text(bandLabel(band.frequency)) }
            }
            Button("Apply equalizer") {
                coordinator.equalizerPreset = .custom
                coordinator.applyEqualizer()
            }
        }
        .onChange(of: coordinator.audioDelay) { value in coordinator.engine.setAudioDelay(value) }
    }

    private var subtitles: some View {
        Section("Subtitles") {
            Toggle("Auto-load sidecar subtitles", isOn: $prefs.subtitlesAuto)
            Slider(value: $prefs.subtitleFontSize, in: 20...90) { Text("Font size") }
            Slider(value: $coordinator.subtitleDelay, in: -10...10) { Text("Delay") }
        }
        .onChange(of: coordinator.subtitleDelay) { value in coordinator.engine.setSubtitleDelay(value) }
        .onChange(of: prefs.subtitleFontSize) { value in
            coordinator.engine.setSubtitleStyle(fontSize: value, color: "#FFFFFFFF", outline: 2, shadow: 1, background: false)
        }
    }

    private var interface: some View {
        Section("Interface") {
            Picker("Control view", selection: $prefs.controlViewStyle) {
                Text("Standard").tag(ControlViewStyle.standard)
                Text("Clean").tag(ControlViewStyle.clean)
            }
            Text("Standard is the current full-width bars. Clean is a floating overlay like QuickTime.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Slider(value: $prefs.hideControlsAfter, in: 0.5...8) { Text("Hide controls after") }
            Toggle("Always on top", isOn: $prefs.alwaysOnTop)
            Toggle("Show statistics overlay", isOn: $prefs.showStatsOverlay)
        }
    }

    private var keyboard: some View {
        Section("Keyboard") {
            ForEach(PlayerCommand.allCases, id: \.self) { command in
                HStack {
                    Text(command.title)
                    Spacer()
                    Text(coordinator.keybindings.chord(for: command)?.display ?? "None")
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
            Button("Restore Defaults") { coordinator.keybindings.restoreDefaults() }
        }
    }

    private var mouse: some View {
        Section("Mouse") {
            Picker("Left click", selection: $prefs.mouse.leftClick) {
                ForEach(ClickAction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Double click", selection: $prefs.mouse.doubleClick) {
                ForEach(ClickAction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Right click", selection: $prefs.mouse.rightClick) {
                ForEach(ClickAction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Middle click", selection: $prefs.mouse.middleClick) {
                ForEach(ClickAction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Wheel", selection: $prefs.mouse.wheel) {
                Text("Volume").tag(WheelAction.volume)
                Text("Seek").tag(WheelAction.seek)
            }
        }
    }

    private var playlist: some View {
        Section("Playlist") {
            Toggle("Remember playlist", isOn: $prefs.rememberPlaylist)
            Toggle("Auto play next", isOn: $prefs.autoPlayNext)
        }
    }

    private var history: some View {
        Section("History") {
            Toggle("Enable history", isOn: $prefs.historyEnabled)
            Button("Clear history") { coordinator.history.clear() }
            ForEach(coordinator.history.groupedByDay(), id: \.0) { group in
                Text(group.0).font(.headline)
                ForEach(group.1) { entry in
                    HStack {
                        Text(entry.title)
                        Spacer()
                        Text(TimeFormatting.clock(entry.position, includeHours: true)).foregroundStyle(.secondary)
                        Button("Remove") { coordinator.history.remove(id: entry.id) }
                    }
                }
            }
        }
    }

    private var network: some View {
        Section("Network") {
            Slider(value: $prefs.network.cacheSeconds, in: 2...60) { Text("Cache seconds") }
            Text("Only HTTP and HTTPS streams are opened through the playback engine. DRM is not bypassed.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var hardware: some View {
        Section("Hardware Acceleration") {
            Picker("Hardware Decoding", selection: $prefs.hardwareDecoding) {
                ForEach(HardwareDecodingMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Text("Decoder: \(coordinator.state.statistics.decoder.isEmpty ? "—" : coordinator.state.statistics.decoder)")
            Text("Hardware: \(coordinator.state.statistics.hardwareDecoding.isEmpty ? "—" : coordinator.state.statistics.hardwareDecoding)")
            Text("Renderer: \(coordinator.state.statistics.renderer.isEmpty ? "OpenGL" : coordinator.state.statistics.renderer)")
            Text("If hardware decoding fails, libmpv falls back to software decoding.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var advanced: some View {
        Section("Advanced") {
            Picker("Screenshot format", selection: $prefs.screenshotFormat) {
                Text("PNG").tag("png")
                Text("JPEG").tag("jpg")
            }
            Toggle("Screenshot with subtitles", isOn: $prefs.screenshotWithSubtitles)
            Button("Export diagnostics") { exportDiagnostics() }
            Text("Raw mpv options are not exposed. Use the settings above; they map to safe engine properties.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func applyLive(_ prefs: AppPreferences) {
        coordinator.engine.setHardwareDecoding(prefs.hardwareDecoding)
        coordinator.engine.setNormalization(prefs.volumeNormalization)
        coordinator.engine.setReplayGain(prefs.replayGain)
        coordinator.engine.setDeinterlace(prefs.deinterlace)
        coordinator.playlistManager.setShuffle(prefs.shuffle)
        coordinator.showStats = prefs.showStatsOverlay
    }

    private func bandLabel(_ frequency: Int) -> String {
        frequency >= 1000 ? "\(frequency / 1000) kHz" : "\(frequency) Hz"
    }

    private func exportDiagnostics() {
        let stats = coordinator.state.statistics
        let text = """
        MacMedia diagnostics
        Decoder: \(stats.decoder)
        Hardware: \(stats.hardwareDecoding)
        Renderer: \(stats.renderer)
        Codec: \(stats.codec)
        Pixel format: \(stats.pixelFormat)
        Resolution: \(stats.width)x\(stats.height)
        FPS: \(stats.fps)
        Dropped: \(stats.droppedFrames)
        Audio: \(stats.audioCodec) \(stats.audioSampleRate)
        """
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacMedia-diagnostics.txt"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, playback, video, audio, subtitles, interface, keyboard, mouse, playlist, history, network, hardware, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .playback: return "Playback"
        case .video: return "Video"
        case .audio: return "Audio"
        case .subtitles: return "Subtitles"
        case .interface: return "Interface"
        case .keyboard: return "Keyboard"
        case .mouse: return "Mouse"
        case .playlist: return "Playlist"
        case .history: return "History"
        case .network: return "Network"
        case .hardware: return "Hardware Acceleration"
        case .advanced: return "Advanced"
        }
    }
}
