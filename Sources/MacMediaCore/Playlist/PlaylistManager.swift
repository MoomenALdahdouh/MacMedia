import Foundation

public struct PlaylistItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var url: URL
    public var title: String

    public init(id: UUID = UUID(), url: URL, title: String? = nil) {
        self.id = id
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
    }
}

public enum PlaylistRepeat: String, Codable, Sendable {
    case off
    case one
    case all
}

public struct PlaylistSnapshot: Codable, Equatable, Sendable {
    public var items: [PlaylistItem]
    public var currentIndex: Int?
    public var shuffle: Bool
    public var repeatMode: PlaylistRepeat

    public init(items: [PlaylistItem] = [], currentIndex: Int? = nil, shuffle: Bool = false, repeatMode: PlaylistRepeat = .off) {
        self.items = items
        self.currentIndex = currentIndex
        self.shuffle = shuffle
        self.repeatMode = repeatMode
    }
}

public final class PlaylistManager: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [PlaylistItem] = []
    private var currentIndex: Int?
    private var shuffleEnabled = false
    private var repeatMode: PlaylistRepeat = .off
    private var shuffleOrder: [Int] = []

    public init() {}

    public var snapshot: PlaylistSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return PlaylistSnapshot(items: items, currentIndex: currentIndex, shuffle: shuffleEnabled, repeatMode: repeatMode)
    }

    public var current: PlaylistItem? {
        lock.lock()
        defer { lock.unlock() }
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return items.count
    }

    public func replace(_ urls: [URL], startAt index: Int = 0) {
        lock.lock()
        items = urls.map { PlaylistItem(url: $0) }
        currentIndex = items.isEmpty ? nil : min(max(index, 0), items.count - 1)
        rebuildShuffleLocked()
        lock.unlock()
    }

    public func append(_ urls: [URL]) {
        lock.lock()
        items.append(contentsOf: urls.map { PlaylistItem(url: $0) })
        if currentIndex == nil, !items.isEmpty {
            currentIndex = 0
        }
        rebuildShuffleLocked()
        lock.unlock()
    }

    public func remove(ids: [UUID]) {
        lock.lock()
        let currentID = currentIndex.flatMap { items.indices.contains($0) ? items[$0].id : nil }
        items.removeAll { ids.contains($0.id) }
        if let currentID {
            currentIndex = items.firstIndex(where: { $0.id == currentID })
        } else {
            currentIndex = items.isEmpty ? nil : 0
        }
        rebuildShuffleLocked()
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        items = []
        currentIndex = nil
        shuffleOrder = []
        lock.unlock()
    }

    public func move(from offsets: IndexSet, to destination: Int) {
        lock.lock()
        var copy = items
        let moving = offsets.sorted().map { copy[$0] }
        for index in offsets.sorted(by: >) {
            copy.remove(at: index)
        }
        var dest = destination
        let removedBefore = offsets.filter { $0 < destination }.count
        dest -= removedBefore
        copy.insert(contentsOf: moving, at: min(dest, copy.count))
        let currentID = currentIndex.flatMap { items.indices.contains($0) ? items[$0].id : nil }
        items = copy
        if let currentID {
            currentIndex = items.firstIndex(where: { $0.id == currentID })
        }
        rebuildShuffleLocked()
        lock.unlock()
    }

    public func setCurrent(id: UUID) -> PlaylistItem? {
        lock.lock()
        defer { lock.unlock() }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        currentIndex = index
        return items[index]
    }

    public func setShuffle(_ enabled: Bool) {
        lock.lock()
        shuffleEnabled = enabled
        rebuildShuffleLocked()
        lock.unlock()
    }

    public func setRepeat(_ mode: PlaylistRepeat) {
        lock.lock()
        repeatMode = mode
        lock.unlock()
    }

    public func restore(_ snapshot: PlaylistSnapshot) {
        lock.lock()
        items = snapshot.items
        currentIndex = snapshot.currentIndex
        shuffleEnabled = snapshot.shuffle
        repeatMode = snapshot.repeatMode
        rebuildShuffleLocked()
        lock.unlock()
    }

    public func next() -> PlaylistItem? {
        lock.lock()
        defer { lock.unlock() }
        guard !items.isEmpty else { return nil }
        if repeatMode == .one, let currentIndex {
            return items[currentIndex]
        }
        guard let following = nextIndexLocked() else { return nil }
        currentIndex = following
        return items.indices.contains(following) ? items[following] : nil
    }

    public func previous() -> PlaylistItem? {
        lock.lock()
        defer { lock.unlock() }
        guard !items.isEmpty else { return nil }
        let preceding = previousIndexLocked()
        currentIndex = preceding
        return preceding.flatMap { items.indices.contains($0) ? items[$0] : nil }
    }

    public func itemAfterEnd() -> PlaylistItem? {
        lock.lock()
        defer { lock.unlock() }
        guard !items.isEmpty else { return nil }
        switch repeatMode {
        case .one:
            return currentIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }
        case .off:
            guard let currentIndex else { return items.first }
            if shuffleEnabled {
                return nextIndexLocked().flatMap { items[$0] }
            }
            let next = currentIndex + 1
            if items.indices.contains(next) {
                self.currentIndex = next
                return items[next]
            }
            return nil
        case .all:
            let following = nextIndexLocked() ?? 0
            currentIndex = following
            return items[following]
        }
    }

    private func nextIndexLocked() -> Int? {
        guard !items.isEmpty else { return nil }
        if shuffleEnabled {
            guard let currentIndex, let position = shuffleOrder.firstIndex(of: currentIndex) else {
                return shuffleOrder.first
            }
            let next = position + 1
            if shuffleOrder.indices.contains(next) { return shuffleOrder[next] }
            return repeatMode == .all ? shuffleOrder.first : nil
        }
        guard let currentIndex else { return 0 }
        let next = currentIndex + 1
        if items.indices.contains(next) { return next }
        return repeatMode == .all ? 0 : nil
    }

    private func previousIndexLocked() -> Int? {
        guard !items.isEmpty else { return nil }
        if shuffleEnabled {
            guard let currentIndex, let position = shuffleOrder.firstIndex(of: currentIndex) else {
                return shuffleOrder.last
            }
            let previous = position - 1
            if shuffleOrder.indices.contains(previous) { return shuffleOrder[previous] }
            return repeatMode == .all ? shuffleOrder.last : shuffleOrder.first
        }
        guard let currentIndex else { return 0 }
        let previous = currentIndex - 1
        if items.indices.contains(previous) { return previous }
        return repeatMode == .all ? items.count - 1 : 0
    }

    private func rebuildShuffleLocked() {
        shuffleOrder = Array(items.indices)
        if shuffleEnabled {
            shuffleOrder.shuffle()
            if let currentIndex, let position = shuffleOrder.firstIndex(of: currentIndex) {
                shuffleOrder.swapAt(0, position)
            }
        }
    }
}

public enum M3UParser {
    public static func parse(_ text: String, base: URL?) -> [URL] {
        var urls: [URL] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if let remote = URL(string: line), let scheme = remote.scheme, ["http", "https", "file"].contains(scheme) {
                urls.append(remote)
                continue
            }
            if line.hasPrefix("/") {
                urls.append(URL(fileURLWithPath: line))
                continue
            }
            if let base {
                urls.append(base.appendingPathComponent(line))
            } else {
                urls.append(URL(fileURLWithPath: line))
            }
        }
        return urls
    }

    public static func serialize(_ urls: [URL]) -> String {
        var lines = ["#EXTM3U"]
        for url in urls {
            lines.append("#EXTINF:-1,\(url.deletingPathExtension().lastPathComponent)")
            lines.append(url.isFileURL ? url.path : url.absoluteString)
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
