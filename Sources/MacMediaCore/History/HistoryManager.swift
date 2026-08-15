import Foundation

public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var url: URL
    public var title: String
    public var position: Double
    public var duration: Double
    public var lastPlayed: Date
    public var audioTrackID: Int?
    public var subtitleTrackID: Int?

    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        position: Double,
        duration: Double,
        lastPlayed: Date = Date(),
        audioTrackID: Int? = nil,
        subtitleTrackID: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.position = position
        self.duration = duration
        self.lastPlayed = lastPlayed
        self.audioTrackID = audioTrackID
        self.subtitleTrackID = subtitleTrackID
    }
}

public enum ResumeDecision: Equatable, Sendable {
    case startOver
    case resume(Double)
    case none
}

public enum ResumePolicy {
    public static func decision(
        position: Double,
        duration: Double,
        enabled: Bool,
        minimumSeconds: Double
    ) -> ResumeDecision {
        guard enabled else { return .none }
        guard duration.isFinite, duration >= minimumSeconds else { return .none }
        guard position.isFinite, position >= 5, position < duration - 5 else { return .none }
        return .resume(position)
    }
}

public final class HistoryManager: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [HistoryEntry] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MacMedia", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MacMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("history.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    public func all() -> [HistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    public func entry(for url: URL) -> HistoryEntry? {
        lock.lock()
        defer { lock.unlock() }
        return entries.first(where: { $0.url == url })
    }

    public func record(
        url: URL,
        position: Double,
        duration: Double,
        audioTrackID: Int?,
        subtitleTrackID: Int?
    ) {
        lock.lock()
        if let index = entries.firstIndex(where: { $0.url == url }) {
            entries[index].position = position
            entries[index].duration = duration
            entries[index].lastPlayed = Date()
            entries[index].audioTrackID = audioTrackID
            entries[index].subtitleTrackID = subtitleTrackID
        } else {
            entries.insert(
                HistoryEntry(
                    url: url,
                    title: url.deletingPathExtension().lastPathComponent,
                    position: position,
                    duration: duration,
                    audioTrackID: audioTrackID,
                    subtitleTrackID: subtitleTrackID
                ),
                at: 0
            )
        }
        if entries.count > 500 {
            entries = Array(entries.prefix(500))
        }
        let snapshot = entries
        lock.unlock()
        save(snapshot)
    }

    public func remove(id: UUID) {
        lock.lock()
        entries.removeAll { $0.id == id }
        let snapshot = entries
        lock.unlock()
        save(snapshot)
    }

    public func clear() {
        lock.lock()
        entries = []
        lock.unlock()
        save([])
    }

    public func groupedByDay() -> [(String, [HistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: all()) { entry -> Date in
            calendar.startOfDay(for: entry.lastPlayed)
        }
        return grouped.keys.sorted(by: >).map { day in
            let label: String
            if calendar.isDateInToday(day) {
                label = "Today"
            } else if calendar.isDateInYesterday(day) {
                label = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                label = formatter.string(from: day)
            }
            let items = grouped[day]?.sorted { $0.lastPlayed > $1.lastPlayed } ?? []
            return (label, items)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? decoder.decode([HistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    private func save(_ entries: [HistoryEntry]) {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLog.persistence.error("History save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
