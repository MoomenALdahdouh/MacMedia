import Foundation
import Testing
@testable import MacMediaCore

@Suite("Time formatting")
struct TimeFormattingTests {
    @Test func clockWithoutHours() {
        #expect(TimeFormatting.clock(75) == "01:15")
    }

    @Test func clockWithHours() {
        #expect(TimeFormatting.clock(3723, includeHours: true) == "01:02:03")
    }

    @Test func parseClock() {
        #expect(TimeFormatting.parseClock("01:02:03") == 3723)
        #expect(TimeFormatting.parseClock("12:30") == 750)
        #expect(TimeFormatting.parseClock("abc") == nil)
    }

    @Test func negativeAndNaN() {
        #expect(TimeFormatting.clock(-1) == "00:00")
        #expect(TimeFormatting.clock(.nan) == "00:00")
    }
}

@Suite("Media file types")
struct MediaFileTypeTests {
    @Test func videoAudioSubtitle() {
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.mkv")) == .video)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.mp3")) == .audio)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.srt")) == .subtitle)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.m3u")) == .playlist)
        #expect(MediaFileType.isPlayable(URL(fileURLWithPath: "/tmp/a.mp4")))
    }

    @Test func unicodeFilenames() {
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/فيلم عربي.mkv")) == .video)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/İstanbul Video.mp4")) == .video)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/电影.mkv")) == .video)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/映画.mp4")) == .video)
        #expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/🎬 Movie.mkv")) == .video)
    }
}

@Suite("Playlist")
struct PlaylistTests {
    @Test func replaceAndNext() {
        let manager = PlaylistManager()
        manager.replace([
            URL(fileURLWithPath: "/tmp/a.mp4"),
            URL(fileURLWithPath: "/tmp/b.mp4")
        ])
        #expect(manager.current?.url.lastPathComponent == "a.mp4")
        #expect(manager.next()?.url.lastPathComponent == "b.mp4")
    }

    @Test func repeatAllWraps() {
        let manager = PlaylistManager()
        manager.replace([URL(fileURLWithPath: "/tmp/a.mp4"), URL(fileURLWithPath: "/tmp/b.mp4")])
        manager.setRepeat(.all)
        _ = manager.next()
        #expect(manager.next()?.url.lastPathComponent == "a.mp4")
    }

    @Test func removeClearsCurrentSafely() {
        let manager = PlaylistManager()
        manager.replace([URL(fileURLWithPath: "/tmp/a.mp4")])
        if let id = manager.current?.id {
            manager.remove(ids: [id])
        }
        #expect(manager.current == nil)
        #expect(manager.count == 0)
    }
}

@Suite("M3U")
struct M3UTests {
    @Test func parseAndSerialize() {
        let text = """
        #EXTM3U
        #EXTINF:-1,One
        /tmp/one.mp4
        https://example.com/two.mkv
        """
        let urls = M3UParser.parse(text, base: URL(fileURLWithPath: "/tmp"))
        #expect(urls.count == 2)
        let serialized = M3UParser.serialize(urls)
        #expect(serialized.contains("#EXTM3U"))
        #expect(serialized.contains("one.mp4"))
    }
}

@Suite("Resume policy")
struct ResumePolicyTests {
    @Test func resumesLongFile() {
        #expect(ResumePolicy.decision(position: 72, duration: 400, enabled: true, minimumSeconds: 30) == .resume(72))
    }

    @Test func skipsShortFile() {
        #expect(ResumePolicy.decision(position: 10, duration: 20, enabled: true, minimumSeconds: 30) == .none)
    }

    @Test func disabled() {
        #expect(ResumePolicy.decision(position: 80, duration: 400, enabled: false, minimumSeconds: 30) == .none)
    }
}

@Suite("Keybindings")
struct KeybindingTests {
    @Test func defaultsAndConflict() {
        let defaults = UserDefaults(suiteName: "macmedia.tests.keybindings")!
        defaults.removePersistentDomain(forName: "macmedia.tests.keybindings")
        let store = KeybindingStore(defaults: defaults)
        #expect(store.command(for: KeyChord(key: " ")) == .playPause)
        let conflict = store.set(KeyChord(key: " "), for: .mute)
        #expect(conflict?.occupant == .playPause)
        store.forceSet(KeyChord(key: " "), for: .mute)
        #expect(store.command(for: KeyChord(key: " ")) == .mute)
        store.restoreDefaults()
        #expect(store.command(for: KeyChord(key: " ")) == .playPause)
    }
}

@Suite("Preferences")
struct PreferencesTests {
    @Test func defaultsAndPersistence() {
        let defaults = UserDefaults(suiteName: "macmedia.tests.prefs")!
        defaults.removePersistentDomain(forName: "macmedia.tests.prefs")
        let manager = PreferencesManager(defaults: defaults)
        #expect(manager.current.hardwareDecoding == .auto)
        #expect(manager.current.rememberPlaybackPosition)
        manager.update { $0.volume = 42 }
        let reloaded = PreferencesManager(defaults: defaults)
        #expect(reloaded.current.volume == 42)
    }
}

@Suite("Equalizer")
struct EqualizerTests {
    @Test func flatHasNoFilter() {
        #expect(EqualizerState().lavfiFilter() == nil)
    }

    @Test func rockHasFilter() {
        #expect(EqualizerPreset.rock.state.lavfiFilter() != nil)
    }
}

@Suite("History")
struct HistoryTests {
    @Test func recordAndRemove() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let history = HistoryManager(directory: dir)
        let url = URL(fileURLWithPath: "/tmp/movie.mkv")
        history.record(url: url, position: 12, duration: 100, audioTrackID: 1, subtitleTrackID: 0)
        #expect(history.entry(for: url)?.position == 12)
        if let id = history.entry(for: url)?.id {
            history.remove(id: id)
        }
        #expect(history.entry(for: url) == nil)
    }
}

@Suite("Media errors")
struct MediaErrorTests {
    @Test func mapping() {
        #expect(MediaError.fromEngine(message: "No such file or directory", path: nil) == .missingFile)
        #expect(MediaError.fromEngine(message: "Permission denied", path: nil) == .permissionDenied)
        #expect(MediaError.fromEngine(message: "unsupported codec", path: nil) == .unsupportedFormat)
    }
}

@Suite("Stress")
struct StressTests {
    @Test func rapidPlaylistOperations() {
        let manager = PlaylistManager()
        let urls = (0..<200).map { URL(fileURLWithPath: "/tmp/item\($0).mp4") }
        manager.replace(urls)
        manager.setShuffle(true)
        for _ in 0..<50 {
            _ = manager.next()
            _ = manager.previous()
        }
        #expect(manager.count == 200)
        manager.clear()
        #expect(manager.count == 0)
    }
}
