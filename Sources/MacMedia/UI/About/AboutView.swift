import AppKit
import SwiftUI
import MacMediaCore

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("MacMedia")
                .font(.title)
            Text("Version \(versionString)")
                .foregroundStyle(.secondary)
            Text("A fast, simple media player for macOS.\nNothing is uploaded. No accounts or ads.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("GitHub") { NSWorkspace.shared.open(AppLinks.github) }
                Button("License") { NSWorkspace.shared.open(AppLinks.license) }
            }
            Divider()
            ScrollView {
                Text(Self.licenseText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(20)
        .frame(width: 440, height: 400)
    }

    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, build != short {
            return "\(short) (\(build))"
        }
        return short
    }

    private static var licenseText: String {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "THIRD_PARTY_LICENSES", withExtension: "md"),
           let text = try? String(contentsOf: url) {
            return text
        }
        return "MacMedia is licensed under GPL-3.0-or-later."
    }
}

struct MediaInfoView: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("File") {
                    row("File", coordinator.state.url?.lastPathComponent ?? "—")
                    row("Container", coordinator.state.statistics.container)
                    row("Duration", TimeFormatting.clock(coordinator.state.duration, includeHours: true))
                    row("File Size", byteCount(coordinator.state.statistics.fileSize))
                }
                section("Video") {
                    row("Codec", coordinator.state.statistics.codec)
                    row("Resolution", "\(coordinator.state.statistics.width)x\(coordinator.state.statistics.height)")
                    row("Frame Rate", String(format: "%.3f", coordinator.state.statistics.fps))
                    row("Pixel Format", coordinator.state.statistics.pixelFormat)
                    row("Color Space", coordinator.state.statistics.colorSpace)
                    row("HDR / Matrix", coordinator.state.statistics.hdr)
                    row("Bitrate", "\(coordinator.state.statistics.videoBitrate)")
                    row("Decoder", coordinator.state.statistics.decoder)
                    row("Hardware", coordinator.state.statistics.hardwareDecoding)
                    row("Renderer", coordinator.state.statistics.renderer)
                }
                section("Audio") {
                    row("Codec", coordinator.state.statistics.audioCodec)
                    row("Sample Rate", "\(coordinator.state.statistics.audioSampleRate)")
                    row("Channels", coordinator.state.statistics.audioChannels)
                    row("Language", coordinator.state.audioTracks.first(where: \.selected)?.language ?? "—")
                }
                section("Subtitles") {
                    row("Track", coordinator.state.subtitleTracks.first(where: \.selected)?.displayName ?? "Off")
                    row("Language", coordinator.state.subtitleTracks.first(where: \.selected)?.language ?? "—")
                    row("Format", coordinator.state.subtitleTracks.first(where: \.selected)?.codec ?? "—")
                }
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 480)
        .onAppear { coordinator.engine.refreshStatistics() }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value).textSelection(.enabled)
        }
        .font(.callout)
    }

    private func byteCount(_ value: Int64) -> String {
        guard value > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
