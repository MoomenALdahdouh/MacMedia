import Foundation

public enum HardwareDecodingMode: String, Codable, CaseIterable, Sendable {
    case auto
    case enabled
    case disabled

    public var mpvValue: String {
        switch self {
        case .auto: return "auto"
        case .enabled: return "videotoolbox"
        case .disabled: return "no"
        }
    }

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        }
    }
}

public enum SeekMode: String, Codable, CaseIterable, Sendable {
    case accurate
    case fast
}

public enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off
    case one
    case all
}

public enum WheelAction: String, Codable, CaseIterable, Sendable {
    case volume
    case seek
}

public enum ControlViewStyle: String, Codable, CaseIterable, Sendable {
    case standard
    case clean

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .clean: return "Clean"
        }
    }
}

public enum ClickAction: String, Codable, CaseIterable, Sendable {
    case none
    case playPause
    case fullscreen
    case contextMenu
    case pause
    case ignore
}

public struct MousePreferences: Codable, Equatable, Sendable {
    public var leftClick: ClickAction = .playPause
    public var doubleClick: ClickAction = .fullscreen
    public var rightClick: ClickAction = .contextMenu
    public var middleClick: ClickAction = .pause
    public var wheel: WheelAction = .volume
    public var shiftWheel: WheelAction = .seek
    public var controlWheel: WheelAction = .seek
    public var commandWheel: WheelAction = .volume
}

public struct NetworkPreferences: Codable, Equatable, Sendable {
    public var cacheSeconds: Double = 10
    public var demuxerMaxBytes: String = "150MiB"
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var hardwareDecoding: HardwareDecodingMode = .auto
    public var rememberPlaybackPosition: Bool = true
    public var autoPlayNext: Bool = true
    public var repeatMode: RepeatMode = .off
    public var shuffle: Bool = false
    public var volumeNormalization: Bool = false
    public var replayGain: Bool = false
    public var subtitlesAuto: Bool = true
    public var rememberPlaylist: Bool = false
    public var historyEnabled: Bool = true
    public var resumeMinimumSeconds: Double = 30
    public var resumePrompt: Bool = true
    public var volume: Double = 80
    public var muted: Bool = false
    public var speed: Double = 1.0
    public var audioPitchCorrection: Bool = true
    public var seekMode: SeekMode = .accurate
    public var shortSeek: Double = 5
    public var longSeek: Double = 60
    public var hideControlsAfter: Double = 2.5
    public var controlViewStyle: ControlViewStyle = .standard
    public var alwaysOnTop: Bool = false
    public var screenshotDirectory: String? = nil
    public var screenshotFormat: String = "png"
    public var screenshotWithSubtitles: Bool = true
    public var playSiblingsInFolder: Bool = false
    public var mouse: MousePreferences = MousePreferences()
    public var network: NetworkPreferences = NetworkPreferences()
    public var subtitleFontSize: Double = 55
    public var subtitleDelay: Double = 0
    public var audioDelay: Double = 0
    public var audioDevice: String = "auto"
    public var deinterlace: Bool = false
    public var oscVisibleByDefault: Bool = true
    public var showStatsOverlay: Bool = false
    public var windowFrame: String? = nil
    public var lastOpenDirectory: String? = nil

    public init() {}
}

public final class PreferencesManager: @unchecked Sendable {
    public static let shared = PreferencesManager()

    private let defaults: UserDefaults
    private let key = "macmedia.preferences.v1"
    private let lock = NSLock()
    private var cached: AppPreferences

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            cached = decoded
        } else {
            cached = AppPreferences()
        }
    }

    public var current: AppPreferences {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    public func update(_ mutate: (inout AppPreferences) -> Void) {
        lock.lock()
        mutate(&cached)
        let snapshot = cached
        lock.unlock()
        persist(snapshot)
    }

    public func replace(_ preferences: AppPreferences) {
        lock.lock()
        cached = preferences
        lock.unlock()
        persist(preferences)
    }

    public func resetToDefaults() {
        replace(AppPreferences())
    }

    private func persist(_ preferences: AppPreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            defaults.set(data, forKey: key)
        } catch {
            AppLog.persistence.error("Failed to persist preferences: \(error.localizedDescription, privacy: .public)")
        }
    }
}
