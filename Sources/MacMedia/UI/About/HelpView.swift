import AppKit
import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MacMedia Help")
                .font(.title2.weight(.semibold))
            Text("Drop a file on the window, or use File → Open (⌘O). Nothing is uploaded.")
                .foregroundStyle(.secondary)

            shortcutTable

            HStack(spacing: 12) {
                Button("GitHub") { NSWorkspace.shared.open(AppLinks.github) }
                Button("Download") { NSWorkspace.shared.open(AppLinks.releases) }
                Button("Report Issue") { NSWorkspace.shared.open(AppLinks.issues) }
            }
            .controlSize(.large)
            Button("Buy me a coffee") { NSWorkspace.shared.open(AppLinks.kofi) }
                .buttonStyle(.link)
                .font(.callout)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 440, height: 420)
    }

    private var shortcutTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shortcuts")
                .font(.headline)
            row("Space", "Play, pause, or replay")
            row("← →", "Seek")
            row("↑ ↓", "Volume")
            row("F", "Fullscreen")
            row("S", "Screenshot (Pictures/MacMedia)")
            row("⌘O", "Open file")
            row("⌘N", "New window")
        }
        .font(.callout)
    }

    private func row(_ keys: String, _ action: String) -> some View {
        HStack {
            Text(keys)
                .font(.body.monospaced())
                .frame(width: 88, alignment: .leading)
            Text(action)
            Spacer()
        }
    }
}
