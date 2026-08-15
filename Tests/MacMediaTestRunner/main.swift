import Foundation
import MacMediaCore

@main
enum MacMediaTestRunner {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #fileID, line: Int = #line) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL \(file):\(line) \(message)")
        }
    }

    static func main() {
        setbuf(stdout, nil)
        print("MacMedia tests starting")
        timeTests()
        fileTypeTests()
        playlistTests()
        m3uTests()
        resumeTests()
        keybindingTests()
        preferenceTests()
        equalizerTests()
        historyTests()
        errorTests()
        stressTests()
        print("engine tests")
        engineTests()
        print("Passed: \(passes)  Failed: \(failures)")
        if failures > 0 {
            exit(1)
        }
        print("UNIT/INTEGRATION/STRESS: PASS")
    }

    static func timeTests() {
        expect(TimeFormatting.clock(75) == "01:15", "clock 75")
        expect(TimeFormatting.clock(3723, includeHours: true) == "01:02:03", "clock hours")
        expect(TimeFormatting.parseClock("01:02:03") == 3723, "parse hms")
        expect(TimeFormatting.parseClock("12:30") == 750, "parse ms")
        expect(TimeFormatting.parseClock("abc") == nil, "parse invalid")
        expect(TimeFormatting.clock(-1) == "00:00", "negative")
        expect(TimeFormatting.clock(.nan) == "00:00", "nan")
    }

    static func fileTypeTests() {
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.mkv")) == .video, "mkv")
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.mp3")) == .audio, "mp3")
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/a.srt")) == .subtitle, "srt")
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/فيلم عربي.mkv")) == .video, "arabic")
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/İstanbul Video.mp4")) == .video, "turkish")
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/电影.mkv")) == .video, "chinese")
        expect(MediaFileType.kind(for: URL(fileURLWithPath: "/tmp/🎬 Movie.mkv")) == .video, "emoji")
    }

    static func playlistTests() {
        let manager = PlaylistManager()
        manager.replace([URL(fileURLWithPath: "/tmp/a.mp4"), URL(fileURLWithPath: "/tmp/b.mp4")])
        expect(manager.current?.url.lastPathComponent == "a.mp4", "current first")
        expect(manager.next()?.url.lastPathComponent == "b.mp4", "next")
        expect(manager.next() == nil, "next at end")
        expect(manager.current?.url.lastPathComponent == "b.mp4", "stay on last")
        manager.setRepeat(.all)
        expect(manager.next()?.url.lastPathComponent == "a.mp4", "wrap")
        if let id = manager.current?.id { manager.remove(ids: [id]) }
        expect(manager.count == 1, "removed one")
        manager.clear()
        expect(manager.count == 0, "cleared")
    }

    static func m3uTests() {
        let text = "#EXTM3U\n/tmp/one.mp4\nhttps://example.com/two.mkv\n"
        let urls = M3UParser.parse(text, base: URL(fileURLWithPath: "/tmp"))
        expect(urls.count == 2, "m3u count")
        expect(M3UParser.serialize(urls).contains("#EXTM3U"), "serialize")
    }

    static func resumeTests() {
        expect(ResumePolicy.decision(position: 72, duration: 400, enabled: true, minimumSeconds: 30) == .resume(72), "resume")
        expect(ResumePolicy.decision(position: 10, duration: 20, enabled: true, minimumSeconds: 30) == .none, "short")
        expect(ResumePolicy.decision(position: 80, duration: 400, enabled: false, minimumSeconds: 30) == .none, "disabled")
    }

    static func keybindingTests() {
        let defaults = UserDefaults(suiteName: "macmedia.tests.keybindings.runner")!
        defaults.removePersistentDomain(forName: "macmedia.tests.keybindings.runner")
        let store = KeybindingStore(defaults: defaults)
        expect(store.command(for: KeyChord(key: " ")) == .playPause, "space")
        let conflict = store.set(KeyChord(key: " "), for: .mute)
        expect(conflict?.occupant == .playPause, "conflict occupant")
        store.forceSet(KeyChord(key: " "), for: .mute)
        expect(store.command(for: KeyChord(key: " ")) == .mute, "reassigned")
        store.restoreDefaults()
        expect(store.command(for: KeyChord(key: " ")) == .playPause, "restored")
    }

    static func preferenceTests() {
        let defaults = UserDefaults(suiteName: "macmedia.tests.prefs.runner")!
        defaults.removePersistentDomain(forName: "macmedia.tests.prefs.runner")
        let manager = PreferencesManager(defaults: defaults)
        expect(manager.current.hardwareDecoding == .auto, "hwdec default")
        expect(manager.current.controlViewStyle == .standard, "standard controls default")
        manager.update { $0.volume = 42 }
        expect(PreferencesManager(defaults: defaults).current.volume == 42, "persisted volume")
        manager.update { $0.controlViewStyle = .clean }
        expect(PreferencesManager(defaults: defaults).current.controlViewStyle == .clean, "persisted clean view")
    }

    static func equalizerTests() {
        expect(EqualizerState().lavfiFilter() == nil, "flat")
        expect(EqualizerPreset.rock.state.lavfiFilter() != nil, "rock")
    }

    static func historyTests() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let history = HistoryManager(directory: dir)
        let url = URL(fileURLWithPath: "/tmp/movie.mkv")
        history.record(url: url, position: 12, duration: 100, audioTrackID: 1, subtitleTrackID: 0)
        expect(history.entry(for: url)?.position == 12, "recorded")
        if let id = history.entry(for: url)?.id { history.remove(id: id) }
        expect(history.entry(for: url) == nil, "removed")
    }

    static func errorTests() {
        expect(MediaError.fromEngine(message: "No such file or directory", path: nil) == .missingFile, "missing")
        expect(MediaError.fromEngine(message: "Permission denied", path: nil) == .permissionDenied, "perm")
        expect(MediaError.fromEngine(message: "unsupported codec", path: nil) == .unsupportedFormat, "unsupported")
    }

    static func stressTests() {
        let manager = PlaylistManager()
        manager.replace((0..<200).map { URL(fileURLWithPath: "/tmp/item\($0).mp4") })
        manager.setShuffle(true)
        for _ in 0..<50 {
            _ = manager.next()
            _ = manager.previous()
        }
        expect(manager.count == 200, "stress count")
        manager.clear()
        expect(manager.count == 0, "stress clear")
    }

    static func engineTests() {
        let generated = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("TestMedia/generated", isDirectory: true)
        let engine = MpvEngine()
        engine.start(configuration: EngineConfiguration(from: AppPreferences(), headless: true))
        defer { engine.shutdown() }

        engine.load(url: URL(fileURLWithPath: "/tmp/macmedia-missing-\(UUID().uuidString).mkv"), startAt: nil)
        wait(until: { engine.state.status == .error }, timeout: 4)
        expect(engine.state.error == .missingFile, "missing file error")

        let h264 = generated.appendingPathComponent("h264_aac.mp4")
        guard FileManager.default.fileExists(atPath: h264.path) else {
            print("SKIP engine media tests (run Scripts/gen-test-media.sh)")
            return
        }
        engine.load(url: h264, startAt: 0)
        wait(until: { engine.state.duration > 0 || engine.state.status == .error }, timeout: 8)
        expect(engine.state.status != .error, "open h264 status=\(engine.state.status) detail=\(engine.state.errorDetail) dur=\(engine.state.duration)")
        engine.pause()
        engine.play()
        engine.seek(to: 1, mode: .accurate)
        engine.setVolume(40)
        engine.setSpeed(1.25)
        wait(until: { abs(engine.state.volume - 40) < 2 }, timeout: 3)
        expect(abs(engine.state.volume - 40) < 2, "volume")

        engine.setHardwareDecoding(.disabled)
        engine.setHardwareDecoding(.auto)

        for name in ["hevc_aac.mp4", "tone.mp3", "h264.mkv", "فيلم عربي.mkv", "corrupt.mp4", "empty.mp4"] {
            let url = generated.appendingPathComponent(name)
            engine.load(url: url, startAt: 0)
            wait(until: { engine.state.status == .error || engine.state.duration > 0 || engine.state.status == .playing || engine.state.status == .paused }, timeout: 6)
            if name.contains("corrupt") || name.contains("empty") {
                expect(true, "corrupt/empty did not crash")
            } else {
                expect(engine.state.status != .error, "open \(name): \(engine.state.errorDetail)")
            }
            engine.stop()
        }
    }

    static func wait(until condition: () -> Bool, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
