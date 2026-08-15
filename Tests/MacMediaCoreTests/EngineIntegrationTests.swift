import Foundation
import Testing
@testable import MacMediaCore

@Suite("libmpv engine")
struct EngineIntegrationTests {
    private var generated: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TestMedia/generated", isDirectory: true)
    }

    @Test func openH264SeekPauseVolumeSpeed() throws {
        let url = generated.appendingPathComponent("h264_aac.mp4")
        try #require(FileManager.default.fileExists(atPath: url.path))
        let engine = MpvEngine()
        defer { engine.shutdown() }
        engine.start(configuration: EngineConfiguration(from: AppPreferences(), headless: true))
        engine.load(url: url, startAt: 0)
        wait(until: { engine.state.duration > 0 || engine.state.status == .error }, timeout: 8)
        #expect(engine.state.status != .error)
        engine.pause()
        engine.play()
        engine.seek(to: 1, mode: .accurate)
        engine.setVolume(40)
        engine.setSpeed(1.25)
        wait(until: { abs(engine.state.volume - 40) < 1 || engine.state.status == .error }, timeout: 3)
        #expect(engine.state.status != .error)
    }

    @Test func missingFileDoesNotCrash() {
        let engine = MpvEngine()
        defer { engine.shutdown() }
        engine.start(configuration: EngineConfiguration(from: AppPreferences(), headless: true))
        engine.load(url: URL(fileURLWithPath: "/tmp/macmedia-missing-\(UUID().uuidString).mkv"), startAt: nil)
        wait(until: { engine.state.status == .error }, timeout: 4)
        #expect(engine.state.error == .missingFile)
    }

    @Test func corruptAndEmptyDoNotCrash() throws {
        let engine = MpvEngine()
        defer { engine.shutdown() }
        engine.start(configuration: EngineConfiguration(from: AppPreferences(), headless: true))
        let corrupt = generated.appendingPathComponent("corrupt.mp4")
        let empty = generated.appendingPathComponent("empty.mp4")
        try #require(FileManager.default.fileExists(atPath: corrupt.path))
        engine.load(url: corrupt, startAt: nil)
        wait(until: { true }, timeout: 1.5)
        engine.load(url: empty, startAt: nil)
        wait(until: { true }, timeout: 1.5)
    }

    @Test func hwdecToggleDoesNotCrash() throws {
        let url = generated.appendingPathComponent("h264_aac.mp4")
        try #require(FileManager.default.fileExists(atPath: url.path))
        let engine = MpvEngine()
        defer { engine.shutdown() }
        engine.start(configuration: EngineConfiguration(from: AppPreferences(), headless: true))
        engine.load(url: url, startAt: 0)
        wait(until: { engine.state.duration > 0 || engine.state.status == .error }, timeout: 6)
        engine.setHardwareDecoding(.disabled)
        engine.setHardwareDecoding(.enabled)
        engine.setHardwareDecoding(.auto)
        #expect(engine.state.status != .error || engine.state.error != .missingFile)
    }

    @Test func hevcAndAudioFiles() throws {
        let engine = MpvEngine()
        defer { engine.shutdown() }
        engine.start(configuration: EngineConfiguration(from: AppPreferences(), headless: true))
        for name in ["hevc_aac.mp4", "tone.mp3", "h264.mkv", "فيلم عربي.mkv"] {
            let url = generated.appendingPathComponent(name)
            try #require(FileManager.default.fileExists(atPath: url.path))
            engine.load(url: url, startAt: 0)
            wait(until: { engine.state.duration > 0 || engine.state.status == .error }, timeout: 8)
            #expect(engine.state.status != .error, "Failed on \(name): \(engine.state.errorDetail)")
            engine.stop()
        }
    }

    private func wait(until condition: () -> Bool, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
