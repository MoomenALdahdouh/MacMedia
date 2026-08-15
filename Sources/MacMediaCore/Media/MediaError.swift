import Foundation

public enum MediaError: Error, Equatable, Sendable {
    case missingFile
    case permissionDenied
    case unsupportedFormat
    case malformedMedia
    case decoderFailure
    case hardwareDecoderFailure
    case audioDeviceFailure
    case subtitleFailure
    case networkFailure
    case renderFailure
    case engineFailure(String)
    case unknown

    public var userMessage: String {
        switch self {
        case .missingFile:
            return "The file could not be found. It may have been moved or deleted."
        case .permissionDenied:
            return "MacMedia does not have permission to open this file."
        case .unsupportedFormat:
            return "The file appears to contain an unsupported or damaged media stream."
        case .malformedMedia:
            return "The file appears to contain an unsupported or damaged media stream."
        case .decoderFailure:
            return "The decoder could not read this media stream."
        case .hardwareDecoderFailure:
            return "Hardware decoding failed. Software decoding will be used if possible."
        case .audioDeviceFailure:
            return "The selected audio device is unavailable."
        case .subtitleFailure:
            return "The subtitle file could not be loaded. Video playback will continue."
        case .networkFailure:
            return "The network stream could not be opened or was interrupted."
        case .renderFailure:
            return "Video rendering failed. Try disabling hardware decoding in Settings."
        case .engineFailure(let detail):
            return "Unable to play this file. \(detail)"
        case .unknown:
            return "Unable to play this file."
        }
    }

    public var title: String {
        "Unable to play this file."
    }

    public static func fromEngine(message: String, path: String?) -> MediaError {
        let lower = message.lowercased()
        if lower.contains("no such file") || lower.contains("not found") || lower.contains("enoent") {
            return .missingFile
        }
        if lower.contains("permission") || lower.contains("eacces") {
            return .permissionDenied
        }
        if lower.contains("http") || lower.contains("network") || lower.contains("tls") || lower.contains("ssl") {
            return .networkFailure
        }
        if lower.contains("unrecognized") || lower.contains("unsupported") || lower.contains("no decoder") {
            return .unsupportedFormat
        }
        if lower.contains("failed to initialize") || lower.contains("error opening") {
            return .malformedMedia
        }
        if !message.isEmpty {
            return .engineFailure(message)
        }
        return .unknown
    }
}
