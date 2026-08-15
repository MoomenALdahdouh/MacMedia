import Foundation
import Carbon.HIToolbox

public enum PlayerCommand: String, Codable, CaseIterable, Sendable {
    case playPause
    case stop
    case seekForward
    case seekBackward
    case seekForwardLarge
    case seekBackwardLarge
    case volumeUp
    case volumeDown
    case mute
    case fullscreen
    case exitFullscreen
    case playlistNext
    case playlistPrevious
    case speedUp
    case speedDown
    case speedReset
    case subtitleDelayPlus
    case subtitleDelayMinus
    case audioDelayPlus
    case audioDelayMinus
    case screenshot
    case frameStepForward
    case frameStepBackward
    case cycleSubtitle
    case cycleAudio
    case togglePlaylist
    case toggleStats
    case openFile
    case jumpToTime
    case chapterNext
    case chapterPrevious
    case toggleAlwaysOnTop
    case pictureInPicture

    public var title: String {
        switch self {
        case .playPause: return "Play/Pause"
        case .stop: return "Stop"
        case .seekForward: return "Seek Forward"
        case .seekBackward: return "Seek Backward"
        case .seekForwardLarge: return "Seek Forward (Large)"
        case .seekBackwardLarge: return "Seek Backward (Large)"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .mute: return "Mute"
        case .fullscreen: return "Fullscreen"
        case .exitFullscreen: return "Exit Fullscreen"
        case .playlistNext: return "Next"
        case .playlistPrevious: return "Previous"
        case .speedUp: return "Speed Up"
        case .speedDown: return "Speed Down"
        case .speedReset: return "Reset Speed"
        case .subtitleDelayPlus: return "Subtitle Delay +"
        case .subtitleDelayMinus: return "Subtitle Delay −"
        case .audioDelayPlus: return "Audio Delay +"
        case .audioDelayMinus: return "Audio Delay −"
        case .screenshot: return "Screenshot"
        case .frameStepForward: return "Frame Step Forward"
        case .frameStepBackward: return "Frame Step Backward"
        case .cycleSubtitle: return "Cycle Subtitle Track"
        case .cycleAudio: return "Cycle Audio Track"
        case .togglePlaylist: return "Toggle Playlist"
        case .toggleStats: return "Toggle Statistics"
        case .openFile: return "Open File"
        case .jumpToTime: return "Jump to Time"
        case .chapterNext: return "Next Chapter"
        case .chapterPrevious: return "Previous Chapter"
        case .toggleAlwaysOnTop: return "Always on Top"
        case .pictureInPicture: return "Picture in Picture"
        }
    }
}

public struct KeyChord: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var shift: Bool
    public var control: Bool
    public var option: Bool
    public var command: Bool

    public init(key: String, shift: Bool = false, control: Bool = false, option: Bool = false, command: Bool = false) {
        self.key = key
        self.shift = shift
        self.control = control
        self.option = option
        self.command = command
    }

    public var display: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(Self.prettyKey(key))
        return parts.joined()
    }

    public static func prettyKey(_ key: String) -> String {
        switch key.lowercased() {
        case " ": return "Space"
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "escape": return "Esc"
        case "return": return "Return"
        case "tab": return "Tab"
        default: return key.uppercased()
        }
    }
}

public struct KeybindingConflict: Equatable, Sendable {
    public let command: PlayerCommand
    public let occupant: PlayerCommand
    public let chord: KeyChord
}

public final class KeybindingStore: @unchecked Sendable {
    public static let shared = KeybindingStore()

    private let defaults: UserDefaults
    private let key = "macmedia.keybindings.v1"
    private let lock = NSLock()
    private var map: [PlayerCommand: KeyChord]

    public static let defaultBindings: [PlayerCommand: KeyChord] = [
        .playPause: KeyChord(key: " "),
        .stop: KeyChord(key: "backspace"),
        .seekBackward: KeyChord(key: "left"),
        .seekForward: KeyChord(key: "right"),
        .seekBackwardLarge: KeyChord(key: "left", shift: true),
        .seekForwardLarge: KeyChord(key: "right", shift: true),
        .volumeUp: KeyChord(key: "up"),
        .volumeDown: KeyChord(key: "down"),
        .mute: KeyChord(key: "m"),
        .fullscreen: KeyChord(key: "f"),
        .exitFullscreen: KeyChord(key: "escape"),
        .playlistNext: KeyChord(key: "n", shift: true),
        .playlistPrevious: KeyChord(key: "p", shift: true),
        .speedUp: KeyChord(key: "]"),
        .speedDown: KeyChord(key: "["),
        .speedReset: KeyChord(key: "\\"),
        .subtitleDelayPlus: KeyChord(key: "z"),
        .subtitleDelayMinus: KeyChord(key: "x"),
        .audioDelayPlus: KeyChord(key: "z", shift: true),
        .audioDelayMinus: KeyChord(key: "x", shift: true),
        .screenshot: KeyChord(key: "s"),
        .frameStepForward: KeyChord(key: "."),
        .frameStepBackward: KeyChord(key: ","),
        .cycleSubtitle: KeyChord(key: "j"),
        .cycleAudio: KeyChord(key: "a", shift: true),
        .togglePlaylist: KeyChord(key: "l"),
        .toggleStats: KeyChord(key: "i"),
        .openFile: KeyChord(key: "o", command: true),
        .jumpToTime: KeyChord(key: "g", command: true),
        .chapterNext: KeyChord(key: "right", option: true),
        .chapterPrevious: KeyChord(key: "left", option: true),
        .toggleAlwaysOnTop: KeyChord(key: "t", command: true),
        .pictureInPicture: KeyChord(key: "p", command: true)
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: KeyChord].self, from: data) {
            var restored: [PlayerCommand: KeyChord] = Self.defaultBindings
            for (raw, chord) in decoded {
                if let command = PlayerCommand(rawValue: raw) {
                    restored[command] = chord
                }
            }
            map = restored
        } else {
            map = Self.defaultBindings
        }
    }

    public var all: [PlayerCommand: KeyChord] {
        lock.lock()
        defer { lock.unlock() }
        return map
    }

    public func chord(for command: PlayerCommand) -> KeyChord? {
        lock.lock()
        defer { lock.unlock() }
        return map[command]
    }

    public func command(for chord: KeyChord) -> PlayerCommand? {
        lock.lock()
        defer { lock.unlock() }
        return map.first(where: { $0.value == chord })?.key
    }

    public func set(_ chord: KeyChord, for command: PlayerCommand) -> KeybindingConflict? {
        lock.lock()
        let occupant = map.first(where: { $0.key != command && $0.value == chord })?.key
        if occupant == nil {
            map[command] = chord
            let snapshot = map
            lock.unlock()
            persist(snapshot)
            return nil
        }
        lock.unlock()
        return KeybindingConflict(command: command, occupant: occupant!, chord: chord)
    }

    public func forceSet(_ chord: KeyChord, for command: PlayerCommand) {
        lock.lock()
        if let occupant = map.first(where: { $0.key != command && $0.value == chord })?.key {
            map[occupant] = KeyChord(key: "")
        }
        map[command] = chord
        let snapshot = map
        lock.unlock()
        persist(snapshot)
    }

    public func restoreDefaults() {
        lock.lock()
        map = Self.defaultBindings
        lock.unlock()
        persist(Self.defaultBindings)
    }

    public func match(key: String, shift: Bool, control: Bool, option: Bool, command: Bool) -> PlayerCommand? {
        let chord = KeyChord(key: key, shift: shift, control: control, option: option, command: command)
        return self.command(for: chord)
    }

    private func persist(_ map: [PlayerCommand: KeyChord]) {
        let encoded = Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            defaults.set(data, forKey: key)
        }
    }
}

public enum KeyEventMapper {
    public static func keyName(from keyCode: UInt16, characters: String?) -> String? {
        switch Int(keyCode) {
        case kVK_Space: return " "
        case kVK_LeftArrow: return "left"
        case kVK_RightArrow: return "right"
        case kVK_UpArrow: return "up"
        case kVK_DownArrow: return "down"
        case kVK_Escape: return "escape"
        case kVK_Delete: return "backspace"
        case kVK_Return: return "return"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        default:
            guard let characters, let first = characters.lowercased().first else { return nil }
            return String(first)
        }
    }
}
