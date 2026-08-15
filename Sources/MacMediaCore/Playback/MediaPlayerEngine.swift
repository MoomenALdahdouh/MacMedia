import Foundation

public enum PlaybackStatus: String, Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case buffering
    case seeking
    case ended
    case error
}

public struct MediaTrack: Equatable, Identifiable, Sendable {
    public var id: Int
    public var type: String
    public var title: String
    public var language: String
    public var codec: String
    public var selected: Bool
    public var hearingImpaired: Bool

    public var displayName: String {
        var parts: [String] = []
        if !language.isEmpty { parts.append(language) }
        if !title.isEmpty { parts.append(title) }
        if !codec.isEmpty { parts.append(codec) }
        if parts.isEmpty { return "Track \(id)" }
        return parts.joined(separator: " · ")
    }
}

public struct ChapterMarker: Equatable, Identifiable, Sendable {
    public var id: Int
    public var title: String
    public var time: Double
}

public struct PlaybackStatistics: Equatable, Sendable {
    public var decoder: String = ""
    public var hardwareDecoding: String = ""
    public var codec: String = ""
    public var pixelFormat: String = ""
    public var renderer: String = ""
    public var gpu: String = ""
    public var width: Int = 0
    public var height: Int = 0
    public var fps: Double = 0
    public var droppedFrames: Int = 0
    public var videoBitrate: Int = 0
    public var audioCodec: String = ""
    public var audioSampleRate: Int = 0
    public var audioChannels: String = ""
    public var subtitleStream: String = ""
    public var container: String = ""
    public var fileSize: Int64 = 0
    public var hdr: String = ""
    public var colorSpace: String = ""
}

public struct PlaybackState: Equatable, Sendable {
    public var status: PlaybackStatus = .idle
    public var url: URL?
    public var title: String = "MacMedia"
    public var position: Double = 0
    public var duration: Double = 0
    public var volume: Double = 80
    public var muted: Bool = false
    public var speed: Double = 1
    public var bufferingPercent: Double = 0
    public var error: MediaError?
    public var errorDetail: String = ""
    public var audioTracks: [MediaTrack] = []
    public var subtitleTracks: [MediaTrack] = []
    public var videoTracks: [MediaTrack] = []
    public var chapters: [ChapterMarker] = []
    public var currentAudioID: Int = 0
    public var currentSubtitleID: Int = 0
    public var statistics: PlaybackStatistics = PlaybackStatistics()
    public var hasVideo: Bool = false
    public var pausedForCache: Bool = false

    public var isPlaying: Bool { status == .playing }
    public var hasMedia: Bool { url != nil }
    public var isFinished: Bool {
        if status == .ended { return true }
        guard duration > 1 else { return false }
        return !isPlaying && position >= max(0, duration - 0.5)
    }
    public var playPauseSystemImage: String {
        if isFinished { return "arrow.counterclockwise" }
        return isPlaying ? "pause.fill" : "play.fill"
    }
    public var playPauseAccessibilityLabel: String {
        if isFinished { return "Replay" }
        return isPlaying ? "Pause" : "Play"
    }
}

public struct EngineConfiguration: Equatable, Sendable {
    public var hardwareDecoding: HardwareDecodingMode
    public var volume: Double
    public var muted: Bool
    public var speed: Double
    public var pitchCorrection: Bool
    public var cacheSeconds: Double
    public var demuxerMaxBytes: String
    public var screenshotDirectory: String?
    public var screenshotFormat: String
    public var subAuto: Bool
    public var audioDevice: String
    public var headless: Bool

    public init(from preferences: AppPreferences, headless: Bool = false) {
        hardwareDecoding = preferences.hardwareDecoding
        volume = preferences.volume
        muted = preferences.muted
        speed = preferences.speed
        pitchCorrection = preferences.audioPitchCorrection
        cacheSeconds = preferences.network.cacheSeconds
        demuxerMaxBytes = preferences.network.demuxerMaxBytes
        screenshotDirectory = preferences.screenshotDirectory
        screenshotFormat = preferences.screenshotFormat
        subAuto = preferences.subtitlesAuto
        audioDevice = preferences.audioDevice
        self.headless = headless
    }
}

public protocol MediaPlayerEngine: AnyObject {
    var state: PlaybackState { get }
    var onStateChange: ((PlaybackState) -> Void)? { get set }
    var onRenderUpdate: (() -> Void)? { get set }

    func start(configuration: EngineConfiguration)
    func shutdown()
    func load(url: URL, startAt: Double?)
    func play()
    func pause()
    func togglePause()
    func stop()
    func seek(to seconds: Double, mode: SeekMode)
    func seekRelative(_ delta: Double, mode: SeekMode)
    func setVolume(_ volume: Double)
    func setMuted(_ muted: Bool)
    func setSpeed(_ speed: Double)
    func frameStep(forward: Bool)
    func setAudioTrack(_ id: Int)
    func setSubtitleTrack(_ id: Int)
    func addSubtitle(url: URL)
    func setSubtitleDelay(_ seconds: Double)
    func setAudioDelay(_ seconds: Double)
    func setSubtitleStyle(fontSize: Double, color: String, outline: Double, shadow: Double, background: Bool)
    func setHardwareDecoding(_ mode: HardwareDecodingMode)
    func setAudioDevice(_ name: String)
    func setEqualizer(_ state: EqualizerState)
    func setNormalization(_ enabled: Bool)
    func setReplayGain(_ enabled: Bool)
    func setColor(_ adjustments: ColorAdjustments)
    func setGeometry(_ geometry: VideoGeometry)
    func setDeinterlace(_ enabled: Bool)
    func screenshot(includeSubtitles: Bool, directory: URL?, format: String) -> URL?
    func setABLoop(a: Double?, b: Double?)
    func cycleABLoop(position: Double)
    func jumpToChapter(_ index: Int)
    func audioDevices() -> [(name: String, description: String)]
    func refreshStatistics()
    func createRenderContextIfNeeded() -> Bool
    func render(fbo: Int32, width: Int32, height: Int32)
    func destroyRenderContext()
    var renderContext: OpaquePointer? { get }
}
