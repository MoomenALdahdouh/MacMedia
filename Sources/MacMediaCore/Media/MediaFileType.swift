import Foundation
import UniformTypeIdentifiers

public enum MediaKind: String, Codable, Sendable {
    case video
    case audio
    case subtitle
    case playlist
    case unknown
}

public enum MediaFileType {
    public static let videoExtensions: Set<String> = [
        "mp4", "mkv", "mov", "avi", "webm", "mpeg", "mpg", "m4v", "ts", "m2ts",
        "mts", "flv", "wmv", "ogv", "3gp", "vob", "m2v", "f4v", "asf", "rmvb",
        "divx", "xvid"
    ]

    public static let audioExtensions: Set<String> = [
        "mp3", "aac", "m4a", "flac", "wav", "aiff", "aif", "ogg", "opus", "alac",
        "wma", "ac3", "dts", "eac3", "mka", "ape", "wv", "oga"
    ]

    public static let subtitleExtensions: Set<String> = [
        "srt", "ass", "ssa", "vtt", "sub", "idx", "sup", "mks"
    ]

    public static let playlistExtensions: Set<String> = [
        "m3u", "m3u8", "pls"
    ]

    public static func kind(for url: URL) -> MediaKind {
        let ext = url.pathExtension.lowercased()
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        if subtitleExtensions.contains(ext) { return .subtitle }
        if playlistExtensions.contains(ext) { return .playlist }
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .audiovisualContent) || type.conforms(to: .mpeg4Movie) || type.conforms(to: .quickTimeMovie) {
                return .video
            }
            if type.conforms(to: .audio) {
                return .audio
            }
            if type.conforms(to: .plainText) && subtitleExtensions.contains(ext) {
                return .subtitle
            }
        }
        return .unknown
    }

    public static func isPlayable(_ url: URL) -> Bool {
        let kind = kind(for: url)
        return kind == .video || kind == .audio
    }

    public static func isSubtitle(_ url: URL) -> Bool {
        kind(for: url) == .subtitle
    }

    public static func isPlaylist(_ url: URL) -> Bool {
        kind(for: url) == .playlist
    }

    /// Extensions advertised to the OS. Actual playback support is determined by libmpv.
    public static var documentExtensions: [String] {
        Array(videoExtensions.union(audioExtensions).union(subtitleExtensions).union(playlistExtensions)).sorted()
    }
}
