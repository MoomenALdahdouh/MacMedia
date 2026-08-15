import SwiftUI
import MacMediaCore

struct PlaylistView: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Playlist")
                    .font(.headline)
                Text("\(coordinator.playlist.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    coordinator.showPlaylist = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Hide playlist")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if coordinator.playlist.items.isEmpty {
                VStack(spacing: 8) {
                    Text("No items")
                        .foregroundStyle(.secondary)
                    Button("Add Files…") { AppDelegate.shared?.openFile() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: {
                        coordinator.playlist.currentIndex.flatMap {
                            coordinator.playlist.items.indices.contains($0) ? coordinator.playlist.items[$0].id : nil
                        }
                    },
                    set: { if let id = $0 { coordinator.playItem(id: id) } }
                )) {
                    ForEach(Array(coordinator.playlist.items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Image(systemName: coordinator.playlist.currentIndex == index ? "speaker.wave.2.fill" : "play.fill")
                                .font(.caption)
                                .foregroundStyle(coordinator.playlist.currentIndex == index ? Color.accentColor : Color.secondary)
                                .frame(width: 14)
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .trailing)
                            Text(item.title)
                                .lineLimit(1)
                            Spacer()
                        }
                        .tag(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture { coordinator.playItem(id: item.id) }
                    }
                    .onMove { source, destination in
                        coordinator.playlistManager.move(from: source, to: destination)
                        coordinator.playlist = coordinator.playlistManager.snapshot
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()
            HStack(spacing: 8) {
                Button("Add…") { AppDelegate.shared?.openFile() }
                Button("Folder…") { AppDelegate.shared?.openFolder() }
                Spacer()
                Button {
                    let enabled = !coordinator.playlist.shuffle
                    coordinator.playlistManager.setShuffle(enabled)
                    coordinator.playlist = coordinator.playlistManager.snapshot
                    coordinator.preferences.update { $0.shuffle = enabled }
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(coordinator.playlist.shuffle ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .help("Shuffle")
                Button("Clear") {
                    coordinator.playlistManager.clear()
                    coordinator.playlist = coordinator.playlistManager.snapshot
                }
            }
            .controlSize(.small)
            .padding(10)
        }
        .accessibilityLabel("Playlist")
    }
}
