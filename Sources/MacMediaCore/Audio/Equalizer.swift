import Foundation

public struct EqualizerBand: Equatable, Sendable, Identifiable {
    public var id: String { "\(frequency)" }
    public var frequency: Int
    public var gain: Double

    public init(frequency: Int, gain: Double = 0) {
        self.frequency = frequency
        self.gain = gain
    }
}

public struct EqualizerState: Equatable, Sendable {
    public var preamp: Double
    public var bands: [EqualizerBand]

    public static let frequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    public init(preamp: Double = 0, bands: [EqualizerBand]? = nil) {
        self.preamp = preamp
        self.bands = bands ?? Self.frequencies.map { EqualizerBand(frequency: $0) }
    }

    public var isFlat: Bool {
        abs(preamp) < 0.01 && bands.allSatisfy { abs($0.gain) < 0.01 }
    }

    public func lavfiFilter() -> String? {
        if isFlat { return nil }
        var parts: [String] = []
        if abs(preamp) >= 0.01 {
            parts.append("volume=\(String(format: "%.2f", preamp))dB")
        }
        for band in bands where abs(band.gain) >= 0.01 {
            parts.append("equalizer=f=\(band.frequency):width_type=o:width=1:g=\(String(format: "%.2f", band.gain))")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ",")
    }
}

public enum EqualizerPreset: String, CaseIterable, Sendable {
    case flat
    case classical
    case rock
    case pop
    case jazz
    case movie
    case speech
    case custom

    public var title: String {
        rawValue.capitalized
    }

    public var state: EqualizerState {
        switch self {
        case .flat, .custom:
            return EqualizerState()
        case .classical:
            return EqualizerState(preamp: 0, bands: gains([0, 0, 0, 0, 0, 0, -2, -3, -3, -4]))
        case .rock:
            return EqualizerState(preamp: -1, bands: gains([4, 3, 2, 0, -1, 0, 2, 3, 4, 4]))
        case .pop:
            return EqualizerState(preamp: -1, bands: gains([-1, 2, 4, 4, 1, -1, -1, 1, 2, 3]))
        case .jazz:
            return EqualizerState(preamp: 0, bands: gains([3, 2, 1, 2, -1, -1, 0, 1, 2, 3]))
        case .movie:
            return EqualizerState(preamp: 0, bands: gains([2, 1, 0, 0, 0, 1, 2, 3, 2, 1]))
        case .speech:
            return EqualizerState(preamp: 0, bands: gains([-4, -3, 1, 4, 5, 4, 2, 0, -2, -4]))
        }
    }

    private static func gains(_ values: [Double]) -> [EqualizerBand] {
        zip(EqualizerState.frequencies, values).map { EqualizerBand(frequency: $0.0, gain: $0.1) }
    }

    private func gains(_ values: [Double]) -> [EqualizerBand] {
        Self.gains(values)
    }
}

public struct ColorAdjustments: Equatable, Sendable {
    public var brightness: Double = 0
    public var contrast: Double = 0
    public var saturation: Double = 0
    public var hue: Double = 0
    public var gamma: Double = 0

    public var isDefault: Bool {
        brightness == 0 && contrast == 0 && saturation == 0 && hue == 0 && gamma == 0
    }
}

public enum AspectMode: String, CaseIterable, Sendable {
    case `default`
    case auto
    case ratio16x9
    case ratio4x3
    case ratio1x1
    case ratio21x9
    case custom

    public var title: String {
        switch self {
        case .default: return "Default"
        case .auto: return "Auto"
        case .ratio16x9: return "16:9"
        case .ratio4x3: return "4:3"
        case .ratio1x1: return "1:1"
        case .ratio21x9: return "21:9"
        case .custom: return "Custom"
        }
    }

    public var mpvValue: String? {
        switch self {
        case .default: return "-1"
        case .auto: return "0"
        case .ratio16x9: return "16:9"
        case .ratio4x3: return "4:3"
        case .ratio1x1: return "1:1"
        case .ratio21x9: return "21:9"
        case .custom: return nil
        }
    }
}

public struct VideoGeometry: Equatable, Sendable {
    public var aspect: AspectMode = .default
    public var customAspect: String = "16:9"
    public var zoom: Double = 1.0
    public var panX: Double = 0
    public var panY: Double = 0
    public var rotate: Int = 0
    public var flipHorizontal: Bool = false
    public var flipVertical: Bool = false

    public static let zoomPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
}

public protocol UpdateChecking: Sendable {
    func checkForUpdates()
}

public struct NoOpUpdateChecker: UpdateChecking {
    public init() {}
    public func checkForUpdates() {}
}
