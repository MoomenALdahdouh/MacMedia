import AppKit
import SwiftUI
import MacMediaCore

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    let history = HistoryManager()
    private var playerWindows: [PlayerWindowController] = []
    private var settingsWindow: SettingsWindowController?
    private var aboutWindow: NSWindow?
    private var helpWindow: NSWindow?
    private var mediaInfoWindow: NSWindow?
    private var menuBuilder: MenuBuilder?
    private var didFinishLaunching = false
    private var pendingLaunchURLs: [URL] = []
    private var lastOpened: (paths: [String], at: Date)?

    var coordinator: PlaybackCoordinator {
        keyPlayer()?.coordinator ?? playerWindows.first?.coordinator ?? PlaybackCoordinator(history: history)
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        menuBuilder = MenuBuilder(history: history)
        menuBuilder?.install()
        didFinishLaunching = true
        let urls = uniqued(pendingLaunchURLs)
        pendingLaunchURLs = []
        if !urls.isEmpty {
            openExternal(urls: urls)
        }
        // Finder file-open can arrive after this method. Wait one turn before
        // creating an untitled window so we do not end up with a blank extra one.
        DispatchQueue.main.async { [weak self] in
            self?.openUntitledWindowIfNeeded()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        enqueueOrOpen(urls: [URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        enqueueOrOpen(urls: urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard didFinishLaunching else { return true }
        if playerWindows.isEmpty {
            openUntitledWindowIfNeeded()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        persistWindowFrame()
        for window in playerWindows {
            window.coordinator.persistSession()
            window.coordinator.engine.onRenderUpdate = nil
            window.coordinator.engine.shutdown()
        }
        playerWindows.removeAll()
    }

    @objc func newPlayerWindow() {
        _ = makePlayerWindow()
    }

    @objc func showSettings() {
        guard let player = keyPlayer() ?? playerWindows.first else {
            _ = makePlayerWindow()
            return showSettings()
        }
        settingsWindow = SettingsWindowController(coordinator: player.coordinator)
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            let controller = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = "About MacMedia"
            window.setContentSize(NSSize(width: 440, height: 400))
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func showHelpWindow() {
        if helpWindow == nil {
            let controller = NSHostingController(rootView: HelpView())
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = "MacMedia Help"
            window.setContentSize(NSSize(width: 440, height: 420))
            helpWindow = window
        }
        helpWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func openGitHub() {
        NSWorkspace.shared.open(AppLinks.github)
    }

    @objc func openReleases() {
        NSWorkspace.shared.open(AppLinks.releases)
    }

    @objc func reportIssue() {
        NSWorkspace.shared.open(AppLinks.issues)
    }

    @objc func openKoFi() {
        NSWorkspace.shared.open(AppLinks.kofi)
    }

    @objc func showMediaInfo() {
        guard let player = keyPlayer() else { return }
        let controller = NSHostingController(rootView: MediaInfoView(coordinator: player.coordinator))
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "Media Information"
        window.setContentSize(NSSize(width: 480, height: 560))
        mediaInfoWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    @objc func openFile() {
        presentOpenPanel(inNewWindow: false)
    }

    @objc func openFileInNewWindow() {
        presentOpenPanel(inNewWindow: true)
    }

    @objc func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.playerForOpening(forceNew: false).coordinator.openFolder(url)
        }
    }

    @objc func openURL() {
        let alert = NSAlert()
        alert.messageText = "Open URL"
        alert.informativeText = "Enter an HTTP or HTTPS media URL."
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "https://"
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn {
            playerForOpening(forceNew: false).coordinator.openURLString(field.stringValue)
        }
    }

    @objc func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        playerForOpening(forceNew: false).coordinator.open(urls: [url])
    }

    @objc func jumpToTime() {
        guard let player = keyPlayer() else { return }
        let alert = NSAlert()
        alert.messageText = "Jump to Time"
        alert.informativeText = "Enter a timestamp such as 01:12:32"
        alert.addButton(withTitle: "Jump")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = TimeFormatting.clock(player.coordinator.state.position, includeHours: true)
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn, let seconds = TimeFormatting.parseClock(field.stringValue) {
            player.coordinator.engine.seek(to: seconds, mode: player.coordinator.preferences.current.seekMode)
        }
    }

    @objc func loadSubtitle() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url, let player = self?.keyPlayer() else { return }
            player.coordinator.engine.addSubtitle(url: url)
        }
    }

    func playerWindowWillClose(_ window: PlayerWindowController) {
        window.coordinator.engine.onRenderUpdate = nil
        window.coordinator.persistSession()
        window.coordinator.engine.shutdown()
        playerWindows.removeAll { $0 === window }
        persistWindowFrame()
    }

    private func presentOpenPanel(inNewWindow: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] result in
            guard result == .OK else { return }
            self?.playerForOpening(forceNew: inNewWindow).coordinator.open(urls: panel.urls)
        }
    }

    private func openUntitledWindowIfNeeded() {
        guard playerWindows.isEmpty else { return }
        let window = makePlayerWindow(restorePlaylist: true, usesFrameAutosave: true)
        restoreWindowFrame(window)
    }

    private func enqueueOrOpen(urls: [URL]) {
        if !didFinishLaunching {
            pendingLaunchURLs.append(contentsOf: urls)
            return
        }
        openExternal(urls: urls)
    }

    private func openExternal(urls: [URL]) {
        let urls = uniqued(urls)
        guard !urls.isEmpty else { return }
        let paths = urls.map(\.standardizedFileURL.path)
        if let last = lastOpened, Date().timeIntervalSince(last.at) < 1.5, last.paths == paths {
            return
        }
        lastOpened = (paths, Date())
        if let idle = idlePlayer() {
            idle.showWindow(nil)
            idle.window?.makeKeyAndOrderFront(nil)
            idle.coordinator.open(urls: urls)
            return
        }
        makePlayerWindow().coordinator.open(urls: urls)
    }

    private func idlePlayer() -> PlayerWindowController? {
        playerWindows.first { !$0.coordinator.state.hasMedia }
    }

    private func uniqued(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.filter { seen.insert($0.standardizedFileURL).inserted }
    }

    private func playerForOpening(forceNew: Bool) -> PlayerWindowController {
        if !forceNew, let player = keyPlayer() {
            player.showWindow(nil)
            return player
        }
        return makePlayerWindow()
    }

    private func keyPlayer() -> PlayerWindowController? {
        if let player = NSApp.keyWindow?.windowController as? PlayerWindowController {
            return player
        }
        if let player = NSApp.mainWindow?.windowController as? PlayerWindowController {
            return player
        }
        return playerWindows.last
    }

    @discardableResult
    private func makePlayerWindow(restorePlaylist: Bool = false, usesFrameAutosave: Bool = false) -> PlayerWindowController {
        let coordinator = PlaybackCoordinator(history: history)
        coordinator.startEngine(headless: false, restoreSavedPlaylist: restorePlaylist)
        let window = PlayerWindowController(coordinator: coordinator, usesFrameAutosave: usesFrameAutosave)
        if !usesFrameAutosave, let source = keyPlayer()?.window?.frame {
            var frame = window.window?.frame ?? source
            frame.origin.x = source.origin.x + 28
            frame.origin.y = source.origin.y - 28
            window.window?.setFrame(frame, display: false)
        }
        playerWindows.append(window)
        window.showWindow(nil)
        window.window?.makeKeyAndOrderFront(nil)
        return window
    }

    private func restoreWindowFrame(_ window: PlayerWindowController) {
        if let stored = PreferencesManager.shared.current.windowFrame {
            window.window?.setFrame(from: stored)
        }
    }

    private func persistWindowFrame() {
        guard let frame = keyPlayer()?.window?.frameDescriptor ?? playerWindows.first?.window?.frameDescriptor else { return }
        PreferencesManager.shared.update { $0.windowFrame = frame }
    }
}
