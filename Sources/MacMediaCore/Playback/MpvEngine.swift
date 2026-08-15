import Foundation
import CMpv
import CoreFoundation

public final class MpvEngine: MediaPlayerEngine, @unchecked Sendable {
    public private(set) var state = PlaybackState()
    public var onStateChange: ((PlaybackState) -> Void)?
    public var onRenderUpdate: (() -> Void)?
    public private(set) var renderContext: OpaquePointer?

    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "app.macmedia.mpv", qos: .userInitiated)
    private var configuration: EngineConfiguration?
    private var equalizer = EqualizerState()
    private var normalization = false
    private var geometry = VideoGeometry()
    private var color = ColorAdjustments()
    private var abLoopA: Double?
    private var abLoopB: Double?
    private var started = false
    private var lastEndWasError = false

    private static let wakeup: @convention(c) (UnsafeMutableRawPointer?) -> Void = { pointer in
        guard let pointer else { return }
        let engine = Unmanaged<MpvEngine>.fromOpaque(pointer).takeUnretainedValue()
        engine.scheduleEventDrain()
    }

    private static let renderUpdate: @convention(c) (UnsafeMutableRawPointer?) -> Void = { pointer in
        guard let pointer else { return }
        let engine = Unmanaged<MpvEngine>.fromOpaque(pointer).takeUnretainedValue()
        engine.onRenderUpdate?()
    }

    private static let getProcAddress: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<Int8>?) -> UnsafeMutableRawPointer? = { _, name in
        guard let name else { return nil }
        let symbol = CFStringCreateWithCString(kCFAllocatorDefault, name, CFStringBuiltInEncodings.ASCII.rawValue)
        let bundle = CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString)
        return CFBundleGetFunctionPointerForName(bundle, symbol)
    }

    public init() {}

    deinit {
        shutdown()
    }

    public func start(configuration: EngineConfiguration) {
        queue.sync {
            self.configuration = configuration
            guard handle == nil else {
                applyConfigurationLocked(configuration)
                return
            }
            guard let created = mpv_create() else {
                publish {
                    $0.status = .error
                    $0.error = .engineFailure("The playback engine could not be created.")
                }
                return
            }
            handle = created
            setOption("terminal", "no")
            setOption("msg-level", "all=warn")
            setOption("vo", configuration.headless ? "null" : "libmpv")
            setOption("ao", configuration.headless ? "null" : "coreaudio")
            setOption("hwdec", configuration.hardwareDecoding.mpvValue)
            setOption("keep-open", "yes")
            setOption("keep-open-pause", "yes")
            setOption("idle", "yes")
            setOption("osc", "no")
            setOption("osd-level", "0")
            setOption("input-default-bindings", "no")
            setOption("input-vo-keyboard", "no")
            setOption("input-cursor", "no")
            setOption("load-scripts", "no")
            setOption("ytdl", "no")
            setOption("force-window", "no")
            setOption("sub-auto", configuration.subAuto ? "fuzzy" : "no")
            setOption("audio-pitch-correction", configuration.pitchCorrection ? "yes" : "no")
            setOption("cache", "yes")
            setOption("demuxer-max-bytes", configuration.demuxerMaxBytes)
            setOption("cache-secs", String(configuration.cacheSeconds))
            setOption("hwdec-codecs", "all")
            if !configuration.headless {
                setOption("vd-lavc-dr", "yes")
                setOption("gpu-api", "opengl")
                setOption("opengl-es", "no")
            }
            if let dir = configuration.screenshotDirectory {
                setOption("screenshot-directory", dir)
            }
            setOption("screenshot-format", configuration.screenshotFormat)
            setOption("screenshot-template", "%F_%tY-%tm-%td_%tH-%tM-%tS")
            mpv_request_log_messages(created, "warn")
            mpv_set_wakeup_callback(created, Self.wakeup, Unmanaged.passUnretained(self).toOpaque())
            let status = mpv_initialize(created)
            if status < 0 {
                publish {
                    $0.status = .error
                    $0.error = .engineFailure(Self.errorString(status))
                }
                return
            }
            observe("pause", format: MPV_FORMAT_FLAG)
            observe("time-pos", format: MPV_FORMAT_DOUBLE)
            observe("duration", format: MPV_FORMAT_DOUBLE)
            observe("volume", format: MPV_FORMAT_DOUBLE)
            observe("mute", format: MPV_FORMAT_FLAG)
            observe("speed", format: MPV_FORMAT_DOUBLE)
            observe("eof-reached", format: MPV_FORMAT_FLAG)
            observe("paused-for-cache", format: MPV_FORMAT_FLAG)
            observe("core-idle", format: MPV_FORMAT_FLAG)
            observe("estimated-vf-fps", format: MPV_FORMAT_DOUBLE)
            observe("decoder-frame-drop-count", format: MPV_FORMAT_INT64)
            observe("video-bitrate", format: MPV_FORMAT_INT64)
            observe("audio-device", format: MPV_FORMAT_STRING)
            observe("hwdec-current", format: MPV_FORMAT_STRING)
            setProperty("volume", String(configuration.volume))
            setProperty("mute", configuration.muted ? "yes" : "no")
            setProperty("speed", String(configuration.speed))
            if configuration.audioDevice != "auto" {
                setProperty("audio-device", configuration.audioDevice)
            }
            started = true
            publish {
                $0.volume = configuration.volume
                $0.muted = configuration.muted
                $0.speed = configuration.speed
            }
            AppLog.engine.info("libmpv initialized")
        }
    }

    public func shutdown() {
        queue.sync {
            destroyRenderContextLocked()
            if let handle {
                mpv_set_wakeup_callback(handle, nil, nil)
                mpv_terminate_destroy(handle)
            }
            handle = nil
            started = false
        }
    }

    public func load(url: URL, startAt: Double?) {
        queue.async { [self] in
            lastEndWasError = false
            if url.isFileURL {
                let path = url.path
                var isDirectory: ObjCBool = false
                if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                    publish {
                        $0.status = .error
                        $0.url = url
                        $0.title = url.deletingPathExtension().lastPathComponent
                        $0.error = .missingFile
                    }
                    return
                }
                if isDirectory.boolValue {
                    publish {
                        $0.status = .error
                        $0.error = .unsupportedFormat
                        $0.url = url
                    }
                    return
                }
                if !FileManager.default.isReadableFile(atPath: path) {
                    publish {
                        $0.status = .error
                        $0.error = .permissionDenied
                        $0.url = url
                    }
                    return
                }
            }
            publish {
                $0.status = .loading
                $0.url = url
                $0.title = url.deletingPathExtension().lastPathComponent
                $0.position = 0
                $0.duration = 0
                $0.error = nil
                $0.errorDetail = ""
            }
            let target = url.isFileURL ? url.path : url.absoluteString
            if let startAt, startAt > 0 {
                command(["loadfile", target, "replace", "0", "start=\(startAt)"])
            } else {
                command(["loadfile", target, "replace"])
            }
            // keep-open-pause leaves pause=yes at EOF; a reload would otherwise stay paused.
            setProperty("pause", "no")
        }
    }

    public func play() { queue.async { self.setProperty("pause", "no") } }
    public func pause() { queue.async { self.setProperty("pause", "yes") } }
    public func togglePause() { queue.async { self.command(["cycle", "pause"]) } }
    public func stop() { queue.async { self.command(["stop"]) } }

    public func seek(to seconds: Double, mode: SeekMode) {
        queue.async {
            let flag = mode == .accurate ? "absolute+exact" : "absolute+keyframes"
            self.command(["seek", String(max(0, seconds)), flag])
        }
    }

    public func seekRelative(_ delta: Double, mode: SeekMode) {
        queue.async {
            let flag = mode == .accurate ? "relative+exact" : "relative+keyframes"
            self.command(["seek", String(delta), flag])
        }
    }

    public func setVolume(_ volume: Double) {
        queue.async {
            let clamped = min(150, max(0, volume))
            self.setProperty("volume", String(clamped))
            self.publish { $0.volume = clamped }
        }
    }

    public func setMuted(_ muted: Bool) {
        queue.async {
            self.setProperty("mute", muted ? "yes" : "no")
            self.publish { $0.muted = muted }
        }
    }

    public func setSpeed(_ speed: Double) {
        queue.async {
            let clamped = min(4, max(0.25, speed))
            self.setProperty("speed", String(clamped))
            self.publish { $0.speed = clamped }
        }
    }

    public func frameStep(forward: Bool) {
        queue.async { self.command([forward ? "frame-step" : "frame-back-step"]) }
    }

    public func setAudioTrack(_ id: Int) {
        queue.async {
            self.setProperty("aid", id == 0 ? "no" : String(id))
            self.publish { $0.currentAudioID = id }
        }
    }

    public func setSubtitleTrack(_ id: Int) {
        queue.async {
            self.setProperty("sid", id == 0 ? "no" : String(id))
            self.publish { $0.currentSubtitleID = id }
        }
    }

    public func addSubtitle(url: URL) {
        queue.async {
            self.command(["sub-add", url.path, "select"])
        }
    }

    public func setSubtitleDelay(_ seconds: Double) {
        queue.async { self.setProperty("sub-delay", String(seconds)) }
    }

    public func setAudioDelay(_ seconds: Double) {
        queue.async { self.setProperty("audio-delay", String(seconds)) }
    }

    public func setSubtitleStyle(fontSize: Double, color: String, outline: Double, shadow: Double, background: Bool) {
        queue.async {
            self.setProperty("sub-font-size", String(fontSize))
            self.setProperty("sub-color", color)
            self.setProperty("sub-border-size", String(outline))
            self.setProperty("sub-shadow-offset", String(shadow))
            self.setProperty("sub-back-color", background ? "#80000000" : "#00000000")
        }
    }

    public func setHardwareDecoding(_ mode: HardwareDecodingMode) {
        queue.async { self.setProperty("hwdec", mode.mpvValue) }
    }

    public func setAudioDevice(_ name: String) {
        queue.async { self.setProperty("audio-device", name) }
    }

    public func setEqualizer(_ state: EqualizerState) {
        queue.async {
            self.equalizer = state
            self.applyAudioFiltersLocked()
        }
    }

    public func setNormalization(_ enabled: Bool) {
        queue.async {
            self.normalization = enabled
            self.applyAudioFiltersLocked()
        }
    }

    public func setReplayGain(_ enabled: Bool) {
        queue.async { self.setProperty("replaygain", enabled ? "track" : "no") }
    }

    public func setColor(_ adjustments: ColorAdjustments) {
        queue.async {
            self.color = adjustments
            self.setProperty("brightness", String(adjustments.brightness))
            self.setProperty("contrast", String(adjustments.contrast))
            self.setProperty("saturation", String(adjustments.saturation))
            self.setProperty("hue", String(adjustments.hue))
            self.setProperty("gamma", String(adjustments.gamma))
        }
    }

    public func setGeometry(_ geometry: VideoGeometry) {
        queue.async {
            self.geometry = geometry
            let aspect = geometry.aspect == .custom ? geometry.customAspect : (geometry.aspect.mpvValue ?? "-1")
            self.setProperty("video-aspect-override", aspect)
            self.setProperty("video-zoom", String(log2(max(0.1, geometry.zoom))))
            self.setProperty("video-pan-x", String(geometry.panX))
            self.setProperty("video-pan-y", String(geometry.panY))
            self.setProperty("video-rotate", String(geometry.rotate))
            var vf: [String] = []
            if geometry.flipHorizontal { vf.append("hflip") }
            if geometry.flipVertical { vf.append("vflip") }
            self.setProperty("vf", vf.joined(separator: ","))
        }
    }

    public func setDeinterlace(_ enabled: Bool) {
        queue.async { self.setProperty("deinterlace", enabled ? "yes" : "no") }
    }

    public func screenshot(includeSubtitles: Bool, directory: URL?, format: String) -> URL? {
        // vo=libmpv cannot take screenshots via screenshot-to-file; the OpenGL
        // path must capture the current framebuffer on the display thread.
        nil
    }

    public func setABLoop(a: Double?, b: Double?) {
        queue.async {
            self.abLoopA = a
            self.abLoopB = b
            self.setProperty("ab-loop-a", a.map { String($0) } ?? "no")
            self.setProperty("ab-loop-b", b.map { String($0) } ?? "no")
        }
    }

    public func cycleABLoop(position: Double) {
        queue.async {
            if self.abLoopA == nil {
                self.abLoopA = position
                self.setProperty("ab-loop-a", String(position))
            } else if self.abLoopB == nil {
                self.abLoopB = position
                self.setProperty("ab-loop-b", String(position))
            } else {
                self.abLoopA = nil
                self.abLoopB = nil
                self.setProperty("ab-loop-a", "no")
                self.setProperty("ab-loop-b", "no")
            }
        }
    }

    public func jumpToChapter(_ index: Int) {
        queue.async { self.setProperty("chapter", String(index)) }
    }

    public func audioDevices() -> [(name: String, description: String)] {
        queue.sync {
            guard let raw = getString("audio-device-list") else { return [("auto", "System Default")] }
            return parseDeviceList(raw)
        }
    }

    public func refreshStatistics() {
        queue.async { self.refreshTracksAndStatsLocked() }
    }

    public func createRenderContextIfNeeded() -> Bool {
        guard renderContext == nil, let handle else { return renderContext != nil }
        var initParams = mpv_opengl_init_params(get_proc_address: Self.getProcAddress, get_proc_address_ctx: nil)
        var advanced: Int32 = 1
        let api = UnsafeMutableRawPointer(mutating: (MPV_RENDER_API_TYPE_OPENGL as NSString).utf8String)
        let status: Int32 = withUnsafeMutablePointer(to: &initParams) { initPtr in
            withUnsafeMutablePointer(to: &advanced) { advPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: api),
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: initPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_ADVANCED_CONTROL, data: advPtr),
                    mpv_render_param()
                ]
                return mpv_render_context_create(&self.renderContext, handle, &params)
            }
        }
        if status < 0 {
            AppLog.render.error("mpv render context failed: \(Self.errorString(status), privacy: .public)")
            return false
        }
        mpv_render_context_set_update_callback(renderContext, Self.renderUpdate, Unmanaged.passUnretained(self).toOpaque())
        AppLog.render.info("mpv OpenGL render context ready")
        return true
    }

    public func render(fbo: Int32, width: Int32, height: Int32) {
        guard let renderContext else { return }
        var framebuffer = mpv_opengl_fbo(fbo: fbo, w: width, h: height, internal_format: 0)
        var flip: Int32 = 1
        withUnsafeMutablePointer(to: &framebuffer) { fboPtr in
            withUnsafeMutablePointer(to: &flip) { flipPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: flipPtr),
                    mpv_render_param()
                ]
                mpv_render_context_render(renderContext, &params)
            }
        }
        mpv_render_context_report_swap(renderContext)
    }

    public func destroyRenderContext() {
        queue.sync { destroyRenderContextLocked() }
    }

    private func destroyRenderContextLocked() {
        if let renderContext {
            mpv_render_context_set_update_callback(renderContext, nil, nil)
            mpv_render_context_free(renderContext)
        }
        renderContext = nil
    }

    private func scheduleEventDrain() {
        queue.async { [self] in
            guard let handle else { return }
            while true {
                let event = mpv_wait_event(handle, 0)
                guard let event, event.pointee.event_id != MPV_EVENT_NONE else { break }
                handleEvent(event.pointee)
            }
        }
    }

    private func handleEvent(_ event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_SHUTDOWN:
            AppLog.engine.info("mpv shutdown")
        case MPV_EVENT_START_FILE:
            lastEndWasError = false
            publish { $0.status = .loading }
        case MPV_EVENT_FILE_LOADED:
            refreshTracksAndStatsLocked()
            let paused = getFlag("pause")
            publish {
                $0.status = paused ? .paused : .playing
                $0.hasVideo = !(self.getString("video-format") ?? "").isEmpty
                $0.duration = self.getDouble("duration")
                $0.title = self.getString("media-title") ?? $0.title
            }
        case MPV_EVENT_END_FILE:
            if let data = event.data?.assumingMemoryBound(to: mpv_event_end_file.self) {
                let reason = data.pointee.reason
                if reason == MPV_END_FILE_REASON_ERROR {
                    lastEndWasError = true
                    let message = Self.errorString(data.pointee.error)
                    AppLog.engine.error("end-file error: \(message, privacy: .public)")
                    publish {
                        $0.status = .error
                        $0.error = MediaError.fromEngine(message: message, path: $0.url?.path)
                        $0.errorDetail = message
                    }
                } else if reason == MPV_END_FILE_REASON_EOF {
                    publish { $0.status = .ended }
                } else if reason == MPV_END_FILE_REASON_STOP || reason == MPV_END_FILE_REASON_QUIT {
                    publish {
                        $0.status = .idle
                        $0.position = 0
                    }
                }
            }
        case MPV_EVENT_SEEK:
            publish { $0.status = .seeking }
        case MPV_EVENT_PLAYBACK_RESTART:
            let paused = getFlag("pause")
            publish { $0.status = paused ? .paused : .playing }
        case MPV_EVENT_VIDEO_RECONFIG, MPV_EVENT_AUDIO_RECONFIG:
            refreshTracksAndStatsLocked()
        case MPV_EVENT_PROPERTY_CHANGE:
            if let property = event.data?.assumingMemoryBound(to: mpv_event_property.self) {
                handleProperty(property.pointee)
            }
        case MPV_EVENT_LOG_MESSAGE:
            if let log = event.data?.assumingMemoryBound(to: mpv_event_log_message.self) {
                let text = String(cString: log.pointee.text)
                let prefix = String(cString: log.pointee.prefix)
                if log.pointee.log_level.rawValue <= MPV_LOG_LEVEL_ERROR.rawValue {
                    AppLog.engine.error("mpv[\(prefix, privacy: .public)] \(text, privacy: .public)")
                }
            }
        default:
            break
        }
    }

    private func handleProperty(_ property: mpv_event_property) {
        let name = String(cString: property.name)
        switch name {
        case "pause":
            if property.format == MPV_FORMAT_FLAG, let value = property.data?.assumingMemoryBound(to: Int32.self) {
                let paused = value.pointee != 0
                publish {
                    if paused, $0.status == .ended { return }
                    $0.status = paused ? .paused : .playing
                }
            }
        case "time-pos":
            if property.format == MPV_FORMAT_DOUBLE, let value = property.data?.assumingMemoryBound(to: Double.self) {
                publish { $0.position = value.pointee }
            }
        case "duration":
            if property.format == MPV_FORMAT_DOUBLE, let value = property.data?.assumingMemoryBound(to: Double.self) {
                publish { $0.duration = value.pointee }
            }
        case "volume":
            if property.format == MPV_FORMAT_DOUBLE, let value = property.data?.assumingMemoryBound(to: Double.self) {
                publish { $0.volume = value.pointee }
            }
        case "mute":
            if property.format == MPV_FORMAT_FLAG, let value = property.data?.assumingMemoryBound(to: Int32.self) {
                publish { $0.muted = value.pointee != 0 }
            }
        case "speed":
            if property.format == MPV_FORMAT_DOUBLE, let value = property.data?.assumingMemoryBound(to: Double.self) {
                publish { $0.speed = value.pointee }
            }
        case "paused-for-cache":
            if property.format == MPV_FORMAT_FLAG, let value = property.data?.assumingMemoryBound(to: Int32.self) {
                let buffering = value.pointee != 0
                publish {
                    $0.pausedForCache = buffering
                    if buffering { $0.status = .buffering }
                }
            }
        case "eof-reached":
            if property.format == MPV_FORMAT_FLAG, let value = property.data?.assumingMemoryBound(to: Int32.self), value.pointee != 0 {
                publish { $0.status = .ended }
            }
        case "estimated-vf-fps":
            if property.format == MPV_FORMAT_DOUBLE, let value = property.data?.assumingMemoryBound(to: Double.self) {
                publish { $0.statistics.fps = value.pointee }
            }
        case "decoder-frame-drop-count":
            if property.format == MPV_FORMAT_INT64, let value = property.data?.assumingMemoryBound(to: Int64.self) {
                publish { $0.statistics.droppedFrames = Int(value.pointee) }
            }
        case "video-bitrate":
            if property.format == MPV_FORMAT_INT64, let value = property.data?.assumingMemoryBound(to: Int64.self) {
                publish { $0.statistics.videoBitrate = Int(value.pointee) }
            }
        case "hwdec-current":
            if let string = stringValue(property) {
                publish { $0.statistics.hardwareDecoding = string }
            }
        default:
            break
        }
    }

    private func refreshTracksAndStatsLocked() {
        let count = Int(getString("track-list/count") ?? "0") ?? 0
        var audio: [MediaTrack] = []
        var subtitles: [MediaTrack] = []
        var video: [MediaTrack] = []
        var audioID = 0
        var subID = 0
        for index in 0..<count {
            let type = getString("track-list/\(index)/type") ?? ""
            let id = Int(getString("track-list/\(index)/id") ?? "0") ?? 0
            let selected = (getString("track-list/\(index)/selected") ?? "") == "yes"
            let track = MediaTrack(
                id: id,
                type: type,
                title: getString("track-list/\(index)/title") ?? "",
                language: getString("track-list/\(index)/lang") ?? "",
                codec: getString("track-list/\(index)/codec") ?? "",
                selected: selected,
                hearingImpaired: (getString("track-list/\(index)/hearing-impaired") ?? "") == "yes"
            )
            switch type {
            case "audio":
                audio.append(track)
                if selected { audioID = id }
            case "sub":
                subtitles.append(track)
                if selected { subID = id }
            case "video":
                video.append(track)
            default:
                break
            }
        }
        let chapterCount = Int(getString("chapter-list/count") ?? "0") ?? 0
        var chapters: [ChapterMarker] = []
        for index in 0..<chapterCount {
            chapters.append(
                ChapterMarker(
                    id: index,
                    title: getString("chapter-list/\(index)/title") ?? "Chapter \(index + 1)",
                    time: Double(getString("chapter-list/\(index)/time") ?? "0") ?? 0
                )
            )
        }
        var stats = state.statistics
        stats.decoder = getString("video-decoder") ?? getString("current-vo") ?? ""
        stats.hardwareDecoding = getString("hwdec-current") ?? "no"
        stats.codec = getString("video-format") ?? ""
        stats.pixelFormat = getString("video-params/pixelformat") ?? ""
        stats.renderer = getString("current-vo") ?? "libmpv"
        stats.gpu = getString("hwdec-current") ?? ""
        stats.width = Int(getString("width") ?? "0") ?? 0
        stats.height = Int(getString("height") ?? "0") ?? 0
        stats.fps = getDouble("estimated-vf-fps")
        stats.droppedFrames = Int(getString("decoder-frame-drop-count") ?? "0") ?? 0
        stats.videoBitrate = Int(getDouble("video-bitrate"))
        stats.audioCodec = getString("audio-codec-name") ?? ""
        stats.audioSampleRate = Int(getString("audio-params/samplerate") ?? "0") ?? 0
        stats.audioChannels = getString("audio-params/hr-channels") ?? ""
        stats.subtitleStream = subtitles.first(where: \.selected)?.displayName ?? "Off"
        stats.container = getString("file-format") ?? ""
        stats.hdr = getString("video-params/colormatrix") ?? ""
        stats.colorSpace = getString("video-params/primaries") ?? ""
        if let path = state.url?.path, let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? NSNumber {
            stats.fileSize = size.int64Value
        }
        publish {
            $0.audioTracks = audio
            $0.subtitleTracks = subtitles
            $0.videoTracks = video
            $0.currentAudioID = audioID
            $0.currentSubtitleID = subID
            $0.chapters = chapters
            $0.statistics = stats
            $0.hasVideo = !video.isEmpty
        }
    }

    private func applyAudioFiltersLocked() {
        var filters: [String] = []
        if let eq = equalizer.lavfiFilter() {
            filters.append("lavfi=[\(eq)]")
        }
        if normalization {
            filters.append("lavfi=[loudnorm]")
        }
        setProperty("af", filters.joined(separator: ","))
    }

    private func applyConfigurationLocked(_ configuration: EngineConfiguration) {
        setProperty("hwdec", configuration.hardwareDecoding.mpvValue)
        setProperty("volume", String(configuration.volume))
        setProperty("mute", configuration.muted ? "yes" : "no")
        setProperty("speed", String(configuration.speed))
        setProperty("audio-pitch-correction", configuration.pitchCorrection ? "yes" : "no")
        setProperty("sub-auto", configuration.subAuto ? "fuzzy" : "no")
        setProperty("cache-secs", String(configuration.cacheSeconds))
        setProperty("demuxer-max-bytes", configuration.demuxerMaxBytes)
    }

    private func observe(_ name: String, format: mpv_format) {
        guard let handle else { return }
        mpv_observe_property(handle, 0, name, format)
    }

    private func setOption(_ name: String, _ value: String) {
        guard let handle else { return }
        mpv_set_option_string(handle, name, value)
    }

    private func setProperty(_ name: String, _ value: String) {
        guard let handle else { return }
        mpv_set_property_string(handle, name, value)
    }

    private func getString(_ name: String) -> String? {
        guard let handle, let pointer = mpv_get_property_string(handle, name) else { return nil }
        defer { mpv_free(pointer) }
        let value = String(cString: pointer)
        return value == "" ? nil : value
    }

    private func getDouble(_ name: String) -> Double {
        Double(getString(name) ?? "") ?? 0
    }

    private func getFlag(_ name: String) -> Bool {
        (getString(name) ?? "") == "yes" || (getString(name) ?? "") == "true"
    }

    private func stringValue(_ property: mpv_event_property) -> String? {
        guard property.format == MPV_FORMAT_STRING,
              let data = property.data?.assumingMemoryBound(to: UnsafePointer<CChar>?.self),
              let pointer = data.pointee else { return nil }
        return String(cString: pointer)
    }

    private func command(_ args: [String]) {
        guard let handle else { return }
        var pointers: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        pointers.append(nil)
        defer { pointers.forEach { free($0) } }
        _ = pointers.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) { rebound in
                mpv_command(handle, rebound)
            }
        }
    }

    private func publish(_ mutate: @escaping (inout PlaybackState) -> Void) {
        mutate(&state)
        let snapshot = state
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(snapshot)
        }
    }

    private func parseDeviceList(_ raw: String) -> [(name: String, description: String)] {
        // mpv audio-device-list as string is not JSON; fall back to auto plus any simple parse.
        if let data = raw.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                let description = (item["description"] as? String) ?? name
                return (name, description)
            }
        }
        return [("auto", "System Default")]
    }

    private static func errorString(_ status: Int32) -> String {
        String(cString: mpv_error_string(status))
    }
}
