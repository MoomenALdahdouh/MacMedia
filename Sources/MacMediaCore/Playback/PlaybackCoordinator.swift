import Foundation

@MainActor
public final class PlaybackCoordinator: ObservableObject {
    @Published public private(set) var state = PlaybackState()
    @Published public var playlist: PlaylistSnapshot = PlaylistSnapshot()
    @Published public var equalizer = EqualizerState()
    @Published public var equalizerPreset: EqualizerPreset = .flat
    @Published public var color = ColorAdjustments()
    @Published public var geometry = VideoGeometry()
    @Published public var showPlaylist = false
    @Published public var showStats = false
    @Published public var showSettings = false
    @Published public var chromeVisible = true
    @Published public var pendingResume: (url: URL, position: Double)?
    @Published public var audioDelay: Double = 0
    @Published public var subtitleDelay: Double = 0
    @Published public var osdMessage: String?
    public var screenshotHandler: (() -> URL?)?

    public let engine: MediaPlayerEngine
    public let playlistManager: PlaylistManager
    public let history: HistoryManager
    public let preferences: PreferencesManager
    public let keybindings: KeybindingStore

    public init(
        engine: MediaPlayerEngine = MpvEngine(),
        playlistManager: PlaylistManager = PlaylistManager(),
        history: HistoryManager = HistoryManager(),
        preferences: PreferencesManager = .shared,
        keybindings: KeybindingStore = .shared
    ) {
        self.engine = engine
        self.playlistManager = playlistManager
        self.history = history
        self.preferences = preferences
        self.keybindings = keybindings
        engine.onStateChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.handleEngineState(snapshot)
            }
        }
    }

    public func startEngine(headless: Bool = false, restoreSavedPlaylist: Bool = true) {
        engine.start(configuration: EngineConfiguration(from: preferences.current, headless: headless))
        applyPreferenceDerivedState()
        if restoreSavedPlaylist,
           preferences.current.rememberPlaylist,
           let snapshot = loadSavedPlaylist() {
            playlistManager.restore(snapshot)
            playlist = playlistManager.snapshot
        }
    }

    public func togglePlayPause(openIfNeeded: () -> Void) {
        if state.isFinished, state.url != nil || playlistManager.current != nil {
            replayCurrent()
            return
        }
        switch state.status {
        case .idle, .ended, .error:
            if let current = playlistManager.current {
                openItem(current, userInitiated: true)
            } else if let first = playlist.items.first {
                playItem(id: first.id)
            } else {
                openIfNeeded()
            }
        default:
            engine.togglePause()
        }
    }

    public func replayCurrent() {
        if let url = playlistManager.current?.url ?? state.url {
            engine.load(url: url, startAt: 0)
            return
        }
        engine.seek(to: 0, mode: .accurate)
        engine.play()
    }

    public func stopPlayback() {
        guard state.url != nil else { return }
        engine.pause()
        engine.seek(to: 0, mode: .accurate)
        flashOSD("Stopped")
    }

    public func skipBackward() {
        engine.seekRelative(-10, mode: preferences.current.seekMode)
    }

    public func skipForward() {
        engine.seekRelative(10, mode: preferences.current.seekMode)
    }

    public func playPrevious() {
        if state.position > 3 {
            engine.seek(to: 0, mode: .accurate)
            return
        }
        let currentID = playlistManager.current?.id
        if let item = playlistManager.previous(), item.id != currentID {
            playlist = playlistManager.snapshot
            openItem(item, userInitiated: true)
        } else {
            engine.seek(to: 0, mode: .accurate)
        }
    }

    public func playNext() {
        if let item = playlistManager.next() {
            playlist = playlistManager.snapshot
            openItem(item, userInitiated: true)
        } else {
            flashOSD("End of playlist")
        }
    }

    public func takeScreenshot() {
        guard state.url != nil else {
            flashOSD("Nothing to capture")
            return
        }
        if let url = screenshotHandler?() {
            flashOSD("Saved \(url.lastPathComponent)")
        } else {
            flashOSD("Screenshot failed")
        }
    }

    public func flashOSD(_ text: String) {
        osdMessage = text
        let token = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if osdMessage == token {
                osdMessage = nil
            }
        }
    }

    public func handle(_ command: PlayerCommand) {
        let prefs = preferences.current
        switch command {
        case .playPause: togglePlayPause(openIfNeeded: {})
        case .stop: stopPlayback()
        case .seekForward: engine.seekRelative(prefs.shortSeek, mode: prefs.seekMode)
        case .seekBackward: engine.seekRelative(-prefs.shortSeek, mode: prefs.seekMode)
        case .seekForwardLarge: engine.seekRelative(prefs.longSeek, mode: prefs.seekMode)
        case .seekBackwardLarge: engine.seekRelative(-prefs.longSeek, mode: prefs.seekMode)
        case .volumeUp: engine.setVolume(state.volume + 5)
        case .volumeDown: engine.setVolume(state.volume - 5)
        case .mute: engine.setMuted(!state.muted)
        case .fullscreen, .exitFullscreen, .togglePlaylist, .toggleStats, .openFile, .jumpToTime, .toggleAlwaysOnTop, .pictureInPicture:
            break
        case .playlistNext: playNext()
        case .playlistPrevious: playPrevious()
        case .speedUp: engine.setSpeed(min(2.0, state.speed + 0.25))
        case .speedDown: engine.setSpeed(max(0.25, state.speed - 0.25))
        case .speedReset: engine.setSpeed(1.0)
        case .subtitleDelayPlus:
            subtitleDelay += 0.1
            engine.setSubtitleDelay(subtitleDelay)
        case .subtitleDelayMinus:
            subtitleDelay -= 0.1
            engine.setSubtitleDelay(subtitleDelay)
        case .audioDelayPlus:
            audioDelay += 0.1
            engine.setAudioDelay(audioDelay)
        case .audioDelayMinus:
            audioDelay -= 0.1
            engine.setAudioDelay(audioDelay)
        case .screenshot:
            takeScreenshot()
        case .frameStepForward: engine.frameStep(forward: true)
        case .frameStepBackward: engine.frameStep(forward: false)
        case .cycleSubtitle: cycle(tracks: state.subtitleTracks, current: state.currentSubtitleID, setter: engine.setSubtitleTrack)
        case .cycleAudio: cycle(tracks: state.audioTracks, current: state.currentAudioID, setter: engine.setAudioTrack)
        case .chapterNext:
            if let current = state.chapters.last(where: { $0.time <= state.position + 0.5 }),
               let index = state.chapters.firstIndex(of: current),
               state.chapters.indices.contains(index + 1) {
                engine.jumpToChapter(index + 1)
            }
        case .chapterPrevious:
            if let current = state.chapters.last(where: { $0.time <= state.position + 0.5 }),
               let index = state.chapters.firstIndex(of: current) {
                engine.jumpToChapter(max(0, index - 1))
            }
        }
    }

    public func open(urls: [URL]) {
        Task {
            let classified = await classify(urls)
            await MainActor.run {
                if classified.subtitles.count == 1, classified.playable.isEmpty, state.hasMedia {
                    engine.addSubtitle(url: classified.subtitles[0])
                    return
                }
                var playable = classified.playable
                if classified.playlists.isEmpty == false {
                    playable.append(contentsOf: classified.playlists)
                }
                guard !playable.isEmpty else { return }
                playlistManager.replace(playable)
                playlist = playlistManager.snapshot
                if let first = playlistManager.current {
                    openItem(first, userInitiated: true)
                }
            }
        }
    }

    public func openFolder(_ url: URL) {
        Task {
            let files = await scanFolder(url)
            await MainActor.run {
                guard !files.isEmpty else { return }
                playlistManager.replace(files)
                playlist = playlistManager.snapshot
                if let first = playlistManager.current {
                    openItem(first, userInitiated: true)
                }
            }
        }
    }

    public func openURLString(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return
        }
        playlistManager.replace([url])
        playlist = playlistManager.snapshot
        if let first = playlistManager.current {
            openItem(first, userInitiated: true)
        }
    }

    public func playItem(id: UUID) {
        if let item = playlistManager.setCurrent(id: id) {
            playlist = playlistManager.snapshot
            openItem(item, userInitiated: true)
        }
    }

    public func resumePending() {
        guard let pending = pendingResume else { return }
        pendingResume = nil
        engine.load(url: pending.url, startAt: pending.position)
    }

    public func startOverPending() {
        guard let pending = pendingResume else { return }
        pendingResume = nil
        engine.load(url: pending.url, startAt: 0)
    }

    public func applyEqualizer() {
        engine.setEqualizer(equalizer)
    }

    public func applyPreset(_ preset: EqualizerPreset) {
        equalizerPreset = preset
        if preset != .custom {
            equalizer = preset.state
        }
        applyEqualizer()
    }

    public func resetVideo() {
        color = ColorAdjustments()
        geometry = VideoGeometry()
        engine.setColor(color)
        engine.setGeometry(geometry)
    }

    public func persistSession() {
        if let url = state.url, preferences.current.historyEnabled {
            history.record(
                url: url,
                position: state.position,
                duration: state.duration,
                audioTrackID: state.currentAudioID,
                subtitleTrackID: state.currentSubtitleID
            )
        }
        preferences.update {
            $0.volume = state.volume
            $0.muted = state.muted
            $0.speed = state.speed
        }
        if preferences.current.rememberPlaylist {
            savePlaylist(playlistManager.snapshot)
        }
    }

    public func loadPlaylistFile(_ url: URL) {
        Task {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let items = M3UParser.parse(text, base: url.deletingLastPathComponent())
            await MainActor.run {
                playlistManager.replace(items)
                playlist = playlistManager.snapshot
                if let first = playlistManager.current {
                    openItem(first, userInitiated: true)
                }
            }
        }
    }

    public func savePlaylist(to url: URL) {
        let text = M3UParser.serialize(playlist.items.map(\.url))
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func openItem(_ item: PlaylistItem, userInitiated: Bool) {
        persistSession()
        let prefs = preferences.current
        if prefs.playSiblingsInFolder, item.url.isFileURL, playlistManager.count <= 1 {
            Task {
                let siblings = await siblingPlayables(around: item.url)
                await MainActor.run {
                    if siblings.count > 1 {
                        let index = siblings.firstIndex(of: item.url) ?? 0
                        playlistManager.replace(siblings, startAt: index)
                        playlist = playlistManager.snapshot
                    }
                    beginPlayback(url: item.url, userInitiated: userInitiated)
                }
            }
            return
        }
        beginPlayback(url: item.url, userInitiated: userInitiated)
    }

    private func beginPlayback(url: URL, userInitiated: Bool) {
        let prefs = preferences.current
        if prefs.historyEnabled, userInitiated, let entry = history.entry(for: url) {
            switch ResumePolicy.decision(
                position: entry.position,
                duration: entry.duration,
                enabled: prefs.rememberPlaybackPosition,
                minimumSeconds: prefs.resumeMinimumSeconds
            ) {
            case .resume(let position) where prefs.resumePrompt:
                pendingResume = (url, position)
                return
            case .resume(let position):
                engine.load(url: url, startAt: position)
                return
            default:
                break
            }
        }
        engine.load(url: url, startAt: 0)
    }

    private func handleEngineState(_ snapshot: PlaybackState) {
        let previous = state.status
        state = snapshot
        if snapshot.status == .ended, previous != .ended, preferences.current.autoPlayNext {
            if let next = playlistManager.itemAfterEnd() {
                playlist = playlistManager.snapshot
                openItem(next, userInitiated: false)
            }
        }
        if snapshot.status == .playing || snapshot.status == .paused {
            showStats = preferences.current.showStatsOverlay || showStats
        }
    }

    private func applyPreferenceDerivedState() {
        let prefs = preferences.current
        engine.setHardwareDecoding(prefs.hardwareDecoding)
        engine.setNormalization(prefs.volumeNormalization)
        engine.setReplayGain(prefs.replayGain)
        engine.setDeinterlace(prefs.deinterlace)
        engine.setSubtitleDelay(prefs.subtitleDelay)
        engine.setAudioDelay(prefs.audioDelay)
        audioDelay = prefs.audioDelay
        subtitleDelay = prefs.subtitleDelay
        playlistManager.setShuffle(prefs.shuffle)
        playlistManager.setRepeat(repeatMode(prefs.repeatMode))
        playlist = playlistManager.snapshot
        showStats = prefs.showStatsOverlay
    }

    private func repeatMode(_ mode: RepeatMode) -> PlaylistRepeat {
        switch mode {
        case .off: return .off
        case .one: return .one
        case .all: return .all
        }
    }

    private func cycle(tracks: [MediaTrack], current: Int, setter: (Int) -> Void) {
        guard !tracks.isEmpty else { return }
        let ids = [0] + tracks.map(\.id)
        let index = ids.firstIndex(of: current) ?? 0
        setter(ids[(index + 1) % ids.count])
    }

    private func classify(_ urls: [URL]) async -> (playable: [URL], subtitles: [URL], playlists: [URL]) {
        var playable: [URL] = []
        var subtitles: [URL] = []
        var playlists: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            if url.isFileURL, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                playable.append(contentsOf: await scanFolder(url))
                continue
            }
            switch MediaFileType.kind(for: url) {
            case .video, .audio: playable.append(url)
            case .subtitle: subtitles.append(url)
            case .playlist:
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                playlists.append(contentsOf: M3UParser.parse(text, base: url.deletingLastPathComponent()))
            case .unknown:
                if url.isFileURL {
                    playable.append(url)
                } else if let scheme = url.scheme, ["http", "https"].contains(scheme) {
                    playable.append(url)
                }
            }
        }
        return (playable, subtitles, playlists)
    }

    private func scanFolder(_ url: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [.isRegularFileKey]
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else { return [] }
            let collected = enumerator.allObjects.compactMap { $0 as? URL }
            var files: [URL] = []
            for file in collected {
                if MediaFileType.isPlayable(file) {
                    files.append(file)
                }
            }
            return files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }.value
    }

    private func siblingPlayables(around url: URL) async -> [URL] {
        let folder = url.deletingLastPathComponent()
        return await Task.detached(priority: .utility) {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            return files.filter(MediaFileType.isPlayable).sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
        }.value
    }

    private var playlistFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("playlist.json")
    }

    private func savePlaylist(_ snapshot: PlaylistSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: playlistFile, options: .atomic)
        }
    }

    private func loadSavedPlaylist() -> PlaylistSnapshot? {
        guard let data = try? Data(contentsOf: playlistFile) else { return nil }
        return try? JSONDecoder().decode(PlaylistSnapshot.self, from: data)
    }
}
