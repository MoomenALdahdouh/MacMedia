import AppKit
import MacMediaCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PlayerWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    let coordinator: PlaybackCoordinator
    private let videoView: VideoView
    private var topBarHost: NSView?
    private var controlBarHost: NSView?
    private var cleanHUDHost: NSView?
    private var playlistHost: NSView?
    private var centerHost: NSView?
    private var statsHost: NSView?
    private var osdHost: NSView?
    private var pipHoverOverlay: PiPHoverOverlay?
    private var hideTimer: Timer?
    private var pipRestore: (frame: NSRect, minSize: NSSize)?
    private var pendingPiP = false

    init(coordinator: PlaybackCoordinator, usesFrameAutosave: Bool = true) {
        self.coordinator = coordinator
        self.videoView = VideoView(engine: coordinator.engine)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacMedia"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 720, height: 420)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.acceptsMouseMovedEvents = true
        window.isRestorable = false
        window.center()
        if usesFrameAutosave {
            window.setFrameAutosaveName("MacMediaPlayer")
        }
        super.init(window: window)
        window.delegate = self
        window.contentView = makeContent()
        coordinator.screenshotHandler = { [weak self] in
            self?.captureAndSaveScreenshot()
        }
        coordinator.engine.onRenderUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.videoView.videoLayer.display()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(stateTick), name: NSApplication.didBecomeActiveNotification, object: nil)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshChrome()
            }
        }
    }

    required init?(coder: NSCoder) { nil }

    private func makeContent() -> NSView {
        let container = PlayerContainerView(coordinator: coordinator)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        videoView.frame = container.bounds
        videoView.autoresizingMask = [.width, .height]
        container.addSubview(videoView)

        let actions = chromeActions()

        let top = interactiveHost(PlayerTopBar(coordinator: coordinator))
        container.addSubview(top)
        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            top.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor)
        ])
        topBarHost = top

        let bottom = interactiveHost(ControlBarView(
            coordinator: coordinator,
            onSettings: actions.onSettings,
            onFullscreen: actions.onFullscreen,
            onPictureInPicture: actions.onPictureInPicture,
            onSpeedMenu: actions.onSpeedMenu,
            onAudioMenu: actions.onAudioMenu,
            onSubtitleMenu: actions.onSubtitleMenu
        ))
        container.addSubview(bottom)
        NSLayoutConstraint.activate([
            bottom.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        controlBarHost = bottom

        let hud = interactiveHost(CleanControlHUD(
            coordinator: coordinator,
            onPictureInPicture: actions.onPictureInPicture,
            onMore: actions.onMore
        ))
        container.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            hud.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
            hud.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -48)
        ])
        cleanHUDHost = hud

        let playlist = interactiveHost(PlaylistSidebar(coordinator: coordinator))
        container.addSubview(playlist)
        NSLayoutConstraint.activate([
            playlist.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            playlist.topAnchor.constraint(equalTo: container.topAnchor),
            playlist.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playlist.widthAnchor.constraint(equalToConstant: 300)
        ])
        playlistHost = playlist

        let center = interactiveHost(PlayerCenterOverlay(coordinator: coordinator))
        container.addSubview(center)
        NSLayoutConstraint.activate([
            center.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            center.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            center.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -40),
            center.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor, constant: -40)
        ])
        centerHost = center

        let stats = displayHost(StatsHost(coordinator: coordinator))
        container.addSubview(stats)
        NSLayoutConstraint.activate([
            stats.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stats.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 8)
        ])
        statsHost = stats

        let osd = displayHost(OSDHost(coordinator: coordinator))
        container.addSubview(osd)
        NSLayoutConstraint.activate([
            osd.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            osd.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        osdHost = osd

        let pipOverlay = PiPHoverOverlay(
            coordinator: coordinator,
            onRestore: { [weak self] in self?.togglePiP() },
            onClose: { [weak self] in self?.window?.performClose(nil) }
        )
        container.addSubview(pipOverlay)
        NSLayoutConstraint.activate([
            pipOverlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pipOverlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pipOverlay.topAnchor.constraint(equalTo: container.topAnchor),
            pipOverlay.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        pipHoverOverlay = pipOverlay

        applyChromeVisibility()
        return container
    }

    private func chromeActions() -> (
        onSettings: () -> Void,
        onFullscreen: () -> Void,
        onPictureInPicture: () -> Void,
        onSpeedMenu: () -> Void,
        onAudioMenu: () -> Void,
        onSubtitleMenu: () -> Void,
        onMore: () -> Void
    ) {
        (
            onSettings: { AppDelegate.shared?.showSettings() },
            onFullscreen: { [weak self] in self?.toggleFullscreen() },
            onPictureInPicture: { [weak self] in self?.togglePiP() },
            onSpeedMenu: { [weak self] in self?.popSpeedMenu() },
            onAudioMenu: { [weak self] in self?.popAudioMenu() },
            onSubtitleMenu: { [weak self] in self?.popSubtitleMenu() },
            onMore: { [weak self] in self?.popMoreMenu() }
        )
    }

    private func interactiveHost<Content: View>(_ view: Content) -> InteractiveHostingView<Content> {
        let host = InteractiveHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = .intrinsicContentSize
        return host
    }

    private func displayHost<Content: View>(_ view: Content) -> DisplayOnlyHostingView<Content> {
        let host = DisplayOnlyHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = .intrinsicContentSize
        return host
    }

    private var showsChrome: Bool {
        coordinator.chromeVisible
            || coordinator.showPlaylist
            || coordinator.state.status == .idle
            || coordinator.state.status == .error
            || coordinator.state.status == .loading
            || !coordinator.state.isPlaying
    }

    private var showsCenterOverlay: Bool {
        let status = coordinator.state.status
        return (status == .idle && coordinator.state.url == nil)
            || status == .loading
            || status == .buffering
            || status == .error
    }

    var isPictureInPicture: Bool { pipRestore != nil }

    private var usesCleanView: Bool {
        coordinator.preferences.current.controlViewStyle == .clean
    }

    private func applyChromeVisibility() {
        if isPictureInPicture {
            topBarHost?.isHidden = true
            controlBarHost?.isHidden = true
            cleanHUDHost?.isHidden = true
            playlistHost?.isHidden = true
            centerHost?.isHidden = true
            statsHost?.isHidden = true
            osdHost?.isHidden = true
            pipHoverOverlay?.setPiPActive(true)
            return
        }
        pipHoverOverlay?.setPiPActive(false)
        let show = showsChrome
        if usesCleanView {
            topBarHost?.isHidden = true
            controlBarHost?.isHidden = true
            cleanHUDHost?.isHidden = !show
        } else {
            topBarHost?.isHidden = !show
            controlBarHost?.isHidden = !show
            cleanHUDHost?.isHidden = true
        }
        playlistHost?.isHidden = !coordinator.showPlaylist
        centerHost?.isHidden = !showsCenterOverlay
        statsHost?.isHidden = !(coordinator.showStats && show)
        osdHost?.isHidden = coordinator.osdMessage == nil
        applyWindowChrome(show: show)
    }

    private func applyWindowChrome(show: Bool) {
        guard let window, !isPictureInPicture else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.standardWindowButton(.closeButton)?.isHidden = !show
        window.standardWindowButton(.miniaturizeButton)?.isHidden = !show
        window.standardWindowButton(.zoomButton)?.isHidden = !show
    }

    func hideChromeIfPlaying() {
        hideTimer?.invalidate()
        hideTimer = nil
        guard coordinator.state.isPlaying, !coordinator.showPlaylist, coordinator.state.status != .error else { return }
        coordinator.chromeVisible = false
        applyChromeVisibility()
    }

    func togglePlaylist() {
        coordinator.showPlaylist.toggle()
    }

    func toggleStats() {
        coordinator.showStats.toggle()
        coordinator.preferences.update { $0.showStatsOverlay = self.coordinator.showStats }
    }

    func toggleAlwaysOnTop() {
        guard let window else { return }
        window.level = window.level == .floating ? .normal : .floating
        coordinator.preferences.update { $0.alwaysOnTop = window.level == .floating }
    }

    func toggleFullscreen() {
        if pipRestore != nil {
            exitPiP()
        }
        window?.toggleFullScreen(nil)
    }

    func togglePiP() {
        if pipRestore != nil {
            exitPiP()
            return
        }
        guard let window else { return }
        if window.styleMask.contains(.fullScreen) {
            pendingPiP = true
            window.toggleFullScreen(nil)
            return
        }
        enterPiP()
    }

    private func enterPiP() {
        guard let window else { return }
        pipRestore = (window.frame, window.minSize)
        window.minSize = NSSize(width: 320, height: 180)
        let size = NSSize(width: 420, height: 236)
        var frame = window.frame
        if let screen = window.screen ?? NSScreen.main {
            let vis = screen.visibleFrame
            frame = NSRect(
                x: vis.maxX - size.width - 24,
                y: vis.minY + 24,
                width: size.width,
                height: size.height
            )
        } else {
            frame.size = size
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.setFrame(frame, display: true, animate: true)
        window.level = .floating
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.acceptsMouseMovedEvents = true
        applyChromeVisibility()
    }

    private func exitPiP() {
        guard let window, let restore = pipRestore else { return }
        pipRestore = nil
        window.minSize = restore.minSize
        window.isMovableByWindowBackground = false
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.setFrame(restore.frame, display: true, animate: true)
        window.level = coordinator.preferences.current.alwaysOnTop ? .floating : .normal
        window.collectionBehavior.remove(.canJoinAllSpaces)
        coordinator.chromeVisible = true
        applyChromeVisibility()
    }

    func popSpeedMenu() {
        let menu = NSMenu()
        for speed in [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0] {
            let title = speed == 1 ? "1× Normal" : String(format: "%.2g×", speed)
            let item = NSMenuItem(title: title, action: #selector(setSpeedFromMenu(_:)), keyEquivalent: "")
            item.representedObject = speed
            item.state = abs(coordinator.state.speed - speed) < 0.01 ? .on : .off
            item.target = self
            menu.addItem(item)
        }
        popMenu(menu)
    }

    func popAudioMenu() {
        let menu = NSMenu()
        let off = NSMenuItem(title: "Off", action: #selector(selectChromeAudio(_:)), keyEquivalent: "")
        off.tag = 0
        off.state = coordinator.state.currentAudioID == 0 ? .on : .off
        off.target = self
        menu.addItem(off)
        if coordinator.state.audioTracks.isEmpty {
            let empty = NSMenuItem(title: "No audio tracks yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for track in coordinator.state.audioTracks {
                let item = NSMenuItem(title: track.displayName, action: #selector(selectChromeAudio(_:)), keyEquivalent: "")
                item.tag = track.id
                item.state = track.selected ? .on : .off
                item.target = self
                menu.addItem(item)
            }
        }
        popMenu(menu)
    }

    func popSubtitleMenu() {
        let menu = NSMenu()
        let off = NSMenuItem(title: "Off", action: #selector(selectChromeSubtitle(_:)), keyEquivalent: "")
        off.tag = 0
        off.state = coordinator.state.currentSubtitleID == 0 ? .on : .off
        off.target = self
        menu.addItem(off)
        if coordinator.state.subtitleTracks.isEmpty {
            let empty = NSMenuItem(title: "No subtitle tracks", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for track in coordinator.state.subtitleTracks {
                let item = NSMenuItem(title: track.displayName, action: #selector(selectChromeSubtitle(_:)), keyEquivalent: "")
                item.tag = track.id
                item.state = track.selected ? .on : .off
                item.target = self
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let load = NSMenuItem(title: "Load Subtitle…", action: #selector(loadChromeSubtitle), keyEquivalent: "")
        load.target = self
        menu.addItem(load)
        popMenu(menu)
    }

    private func popMenu(_ menu: NSMenu) {
        guard let window, let contentView = window.contentView else { return }
        var location = window.mouseLocationOutsideOfEventStream
        location = contentView.convert(location, from: nil)
        menu.popUp(positioning: nil, at: location, in: contentView)
    }

    @objc private func selectChromeAudio(_ sender: NSMenuItem) {
        coordinator.engine.setAudioTrack(sender.tag)
    }

    @objc private func selectChromeSubtitle(_ sender: NSMenuItem) {
        coordinator.engine.setSubtitleTrack(sender.tag)
    }

    @objc private func loadChromeSubtitle() {
        AppDelegate.shared?.loadSubtitle()
    }

    func popMoreMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Speed", action: #selector(showSpeedFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Audio Track", action: #selector(showAudioFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Subtitles", action: #selector(showSubtitleFromMore), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Previous", action: #selector(previousFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Next", action: #selector(nextFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Stop", action: #selector(stopFromMore), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Screenshot", action: #selector(screenshotFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Playlist", action: #selector(playlistFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Fullscreen", action: #selector(fullscreenFromMore), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(settingsFromMore), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        popMenu(menu)
    }

    @objc private func showSpeedFromMore() { popSpeedMenu() }
    @objc private func showAudioFromMore() { popAudioMenu() }
    @objc private func showSubtitleFromMore() { popSubtitleMenu() }
    @objc private func previousFromMore() { coordinator.playPrevious() }
    @objc private func nextFromMore() { coordinator.playNext() }
    @objc private func stopFromMore() { coordinator.stopPlayback() }
    @objc private func screenshotFromMore() { coordinator.takeScreenshot() }
    @objc private func playlistFromMore() { togglePlaylist() }
    @objc private func fullscreenFromMore() { toggleFullscreen() }
    @objc private func settingsFromMore() { AppDelegate.shared?.showSettings() }

    @objc func toggleCleanView() {
        let next: ControlViewStyle = usesCleanView ? .standard : .clean
        coordinator.preferences.update { $0.controlViewStyle = next }
        applyChromeVisibility()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleCleanView) {
            menuItem.state = usesCleanView ? .on : .off
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        AppDelegate.shared?.playerWindowWillClose(self)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        hideCursorSoon()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        NSCursor.unhide()
        applyWindowChrome(show: showsChrome)
        if pendingPiP {
            pendingPiP = false
            enterPiP()
        }
    }

    @objc private func stateTick() {
        refreshChrome()
    }

    private func refreshChrome() {
        window?.title = coordinator.state.title.isEmpty ? "MacMedia" : coordinator.state.title
        if !isPictureInPicture,
           !coordinator.state.isPlaying || coordinator.state.status == .error || coordinator.state.status == .idle {
            coordinator.chromeVisible = true
        }
        if coordinator.preferences.current.alwaysOnTop || isPictureInPicture {
            window?.level = .floating
        }
        if coordinator.pendingResume != nil {
            presentResumeIfNeeded()
        }
        pipHoverOverlay?.refresh()
        applyChromeVisibility()
    }

    private var didPresentResume = false
    private func presentResumeIfNeeded() {
        guard let pending = coordinator.pendingResume, !didPresentResume else { return }
        didPresentResume = true
        let alert = NSAlert()
        alert.messageText = "Resume playback?"
        alert.informativeText = "Resume from \(TimeFormatting.clock(pending.position, includeHours: true))?"
        alert.addButton(withTitle: "Resume")
        alert.addButton(withTitle: "Start Over")
        let response = alert.runModal()
        didPresentResume = false
        if response == .alertFirstButtonReturn {
            coordinator.resumePending()
        } else {
            coordinator.startOverPending()
        }
    }

    func noteMouseMoved() {
        coordinator.chromeVisible = true
        applyChromeVisibility()
        NSCursor.unhide()
        hideTimer?.invalidate()
        let delay = coordinator.preferences.current.hideControlsAfter
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.coordinator.state.isPlaying,
                   !self.coordinator.showPlaylist,
                   self.coordinator.state.status != .error {
                    self.coordinator.chromeVisible = false
                    self.applyChromeVisibility()
                    if self.window?.styleMask.contains(.fullScreen) == true {
                        NSCursor.setHiddenUntilMouseMoves(true)
                    }
                }
            }
        }
    }

    func hidePiPHoverControls() {
        pipHoverOverlay?.hideControls()
    }

    private func hideCursorSoon() {
        noteMouseMoved()
    }

    private func captureAndSaveScreenshot() -> URL? {
        let prefs = coordinator.preferences.current
        guard let image = videoView.videoLayer.captureBitmap() else { return nil }
        let format = prefs.screenshotFormat.lowercased()
        let data: Data?
        if format == "jpg" || format == "jpeg" {
            data = image.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        } else {
            data = image.representation(using: .png, properties: [:])
        }
        guard let data else { return nil }

        let folder: URL
        if let custom = prefs.screenshotDirectory, !custom.isEmpty {
            folder = URL(fileURLWithPath: custom, isDirectory: true)
        } else if let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            folder = pictures.appendingPathComponent("MacMedia", isDirectory: true)
        } else {
            folder = FileManager.default.temporaryDirectory
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let rawTitle = coordinator.state.title.isEmpty ? "MacMedia" : coordinator.state.title
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let base = rawTitle.components(separatedBy: invalid).joined(separator: "_")
        let ext = (format == "jpg" || format == "jpeg") ? "jpg" : "png"
        let url = folder.appendingPathComponent("\(base)_\(formatter.string(from: Date())).\(ext)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

@MainActor
final class PlayerContainerView: NSView {
    let coordinator: PlaybackCoordinator

    init(coordinator: PlaybackCoordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL, .URL])
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func mouseMoved(with event: NSEvent) {
        (window?.windowController as? PlayerWindowController)?.noteMouseMoved()
    }

    override func mouseExited(with event: NSEvent) {
        let controller = window?.windowController as? PlayerWindowController
        controller?.hidePiPHoverControls()
        controller?.hideChromeIfPlaying()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseDown(with event: NSEvent) {
        handleClick(event, action: coordinator.preferences.current.mouse.leftClick, isDouble: event.clickCount == 2)
    }

    override func rightMouseDown(with event: NSEvent) {
        handleClick(event, action: coordinator.preferences.current.mouse.rightClick, isDouble: false)
    }

    override func otherMouseDown(with event: NSEvent) {
        handleClick(event, action: coordinator.preferences.current.mouse.middleClick, isDouble: false)
    }

    override func scrollWheel(with event: NSEvent) {
        let prefs = coordinator.preferences.current.mouse
        let action: WheelAction
        if event.modifierFlags.contains(.shift) {
            action = prefs.shiftWheel
        } else if event.modifierFlags.contains(.control) {
            action = prefs.controlWheel
        } else if event.modifierFlags.contains(.command) {
            action = prefs.commandWheel
        } else {
            action = prefs.wheel
        }
        let delta = event.scrollingDeltaY
        switch action {
        case .volume:
            coordinator.engine.setVolume(coordinator.state.volume + (delta > 0 ? 2 : -2))
        case .seek:
            coordinator.engine.seekRelative(delta > 0 ? 5 : -5, mode: coordinator.preferences.current.seekMode)
        }
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let name = KeyEventMapper.keyName(from: event.keyCode, characters: event.charactersIgnoringModifiers)
        guard let name else {
            super.keyDown(with: event)
            return
        }
        if let command = coordinator.keybindings.match(
            key: name,
            shift: flags.contains(.shift),
            control: flags.contains(.control),
            option: flags.contains(.option),
            command: flags.contains(.command)
        ) {
            dispatch(command)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]) ?? []
        coordinator.open(urls: urls)
        return !urls.isEmpty
    }

    private func handleClick(_ event: NSEvent, action: ClickAction, isDouble: Bool) {
        if let player = window?.windowController as? PlayerWindowController, player.isPictureInPicture {
            if isDouble {
                player.togglePiP()
            } else {
                coordinator.togglePlayPause { AppDelegate.shared?.openFile() }
            }
            return
        }
        let resolved = isDouble ? coordinator.preferences.current.mouse.doubleClick : action
        switch resolved {
        case .none, .ignore: break
        case .playPause, .pause:
            coordinator.togglePlayPause { AppDelegate.shared?.openFile() }
        case .fullscreen:
            (window?.windowController as? PlayerWindowController)?.toggleFullscreen()
        case .contextMenu: NSMenu.popUpContextMenu(contextMenu(), with: event, for: self)
        }
        (window?.windowController as? PlayerWindowController)?.noteMouseMoved()
    }

    private func dispatch(_ command: PlayerCommand) {
        switch command {
        case .playPause:
            coordinator.togglePlayPause { AppDelegate.shared?.openFile() }
        case .fullscreen:
            (window?.windowController as? PlayerWindowController)?.toggleFullscreen()
        case .exitFullscreen:
            if window?.styleMask.contains(.fullScreen) == true {
                window?.toggleFullScreen(nil)
            }
        case .togglePlaylist: (window?.windowController as? PlayerWindowController)?.togglePlaylist()
        case .toggleStats: (window?.windowController as? PlayerWindowController)?.toggleStats()
        case .openFile: AppDelegate.shared?.openFile()
        case .jumpToTime: AppDelegate.shared?.jumpToTime()
        case .toggleAlwaysOnTop: (window?.windowController as? PlayerWindowController)?.toggleAlwaysOnTop()
        case .pictureInPicture: (window?.windowController as? PlayerWindowController)?.togglePiP()
        default:
            coordinator.handle(command)
        }
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: coordinator.state.playPauseAccessibilityLabel, action: #selector(playPauseAction), keyEquivalent: "")
        menu.addItem(withTitle: "Stop", action: #selector(stopAction), keyEquivalent: "")
        menu.addItem(withTitle: "Fullscreen", action: #selector(fullscreenAction), keyEquivalent: "")
        menu.addItem(.separator())
        addTrackMenu(menu, title: "Audio Track", tracks: coordinator.state.audioTracks, current: coordinator.state.currentAudioID, selector: #selector(selectAudio(_:)))
        addTrackMenu(menu, title: "Subtitle Track", tracks: coordinator.state.subtitleTracks, current: coordinator.state.currentSubtitleID, selector: #selector(selectSubtitle(_:)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Screenshot", action: #selector(screenshotAction), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(settingsAction), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func addTrackMenu(_ menu: NSMenu, title: String, tracks: [MediaTrack], current: Int, selector: Selector) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let off = NSMenuItem(title: "Off", action: selector, keyEquivalent: "")
        off.tag = 0
        off.state = current == 0 ? .on : .off
        off.target = self
        submenu.addItem(off)
        for track in tracks {
            let child = NSMenuItem(title: track.displayName, action: selector, keyEquivalent: "")
            child.tag = track.id
            child.state = track.selected ? .on : .off
            child.target = self
            submenu.addItem(child)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    @objc private func playPauseAction() {
        coordinator.togglePlayPause { AppDelegate.shared?.openFile() }
    }
    @objc private func stopAction() { coordinator.stopPlayback() }
    @objc private func fullscreenAction() {
        (window?.windowController as? PlayerWindowController)?.toggleFullscreen()
    }
    @objc private func screenshotAction() { coordinator.takeScreenshot() }
    @objc private func settingsAction() { AppDelegate.shared?.showSettings() }
    @objc private func selectAudio(_ sender: NSMenuItem) { coordinator.engine.setAudioTrack(sender.tag) }
    @objc private func selectSubtitle(_ sender: NSMenuItem) { coordinator.engine.setSubtitleTrack(sender.tag) }
}

struct StatsHost: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        StatsOverlay(state: coordinator.state)
            .padding(4)
    }
}

struct OSDHost: View {
    @ObservedObject var coordinator: PlaybackCoordinator

    var body: some View {
        if let message = coordinator.osdMessage {
            PlayerOSD(message: message)
        }
    }
}

@MainActor
final class PiPHoverOverlay: NSView {
    private let coordinator: PlaybackCoordinator
    private let onRestore: () -> Void
    private let onClose: () -> Void
    private let restoreButton: NSButton
    private let closeButton: NSButton
    private let backButton: NSButton
    private let playButton: NSButton
    private let nextButton: NSButton
    private var pipMode = false
    private var hideTimer: Timer?

    init(coordinator: PlaybackCoordinator, onRestore: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onRestore = onRestore
        self.onClose = onClose
        restoreButton = PiPHoverOverlay.plainButton("pip.exit", size: 28)
        closeButton = PiPHoverOverlay.plainButton("xmark", size: 26)
        backButton = PiPHoverOverlay.plainButton("backward.fill", size: 26)
        playButton = PiPHoverOverlay.plainButton("play.fill", size: 36)
        nextButton = PiPHoverOverlay.plainButton("forward.fill", size: 26)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        restoreButton.target = self
        closeButton.target = self
        backButton.target = self
        playButton.target = self
        nextButton.target = self
        restoreButton.action = #selector(restore)
        closeButton.action = #selector(closePlayer)
        backButton.action = #selector(goPrevious)
        playButton.action = #selector(playPause)
        nextButton.action = #selector(goNext)
        restoreButton.toolTip = "Exit Picture in Picture"
        closeButton.toolTip = "Close"
        backButton.toolTip = "Previous"
        playButton.toolTip = "Play/Pause"
        nextButton.toolTip = "Next"
        layoutChrome()
        setButtonsVisible(false)
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        guard pipMode else { return }
        showControls()
    }

    override func mouseMoved(with event: NSEvent) {
        guard pipMode else { return }
        showControls()
    }

    override func mouseExited(with event: NSEvent) {
        hideControls()
    }

    func setPiPActive(_ active: Bool) {
        let wasActive = pipMode
        pipMode = active
        isHidden = !active
        if active {
            refresh()
            if !wasActive {
                hideControls()
            }
        } else {
            hideControls()
        }
    }

    func refresh() {
        let name = coordinator.state.playPauseSystemImage
        let help = coordinator.state.playPauseAccessibilityLabel
        playButton.image = NSImage(systemSymbolName: name, accessibilityDescription: help)
        playButton.toolTip = help
    }

    func hideControls() {
        hideTimer?.invalidate()
        hideTimer = nil
        setButtonsVisible(false)
    }

    private func showControls() {
        hideTimer?.invalidate()
        hideTimer = nil
        setButtonsVisible(true)
    }

    private func layoutChrome() {
        addSubview(restoreButton)
        addSubview(closeButton)
        addSubview(backButton)
        addSubview(playButton)
        addSubview(nextButton)

        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            restoreButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -6),
            restoreButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            playButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -16),
            backButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            nextButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 16),
            nextButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor)
        ])
    }

    private func setButtonsVisible(_ visible: Bool) {
        restoreButton.isHidden = !visible
        closeButton.isHidden = !visible
        backButton.isHidden = !visible
        playButton.isHidden = !visible
        nextButton.isHidden = !visible
    }

    @objc private func restore() { onRestore() }
    @objc private func closePlayer() { onClose() }
    @objc private func goPrevious() { coordinator.playPrevious() }
    @objc private func playPause() { coordinator.togglePlayPause {} }
    @objc private func goNext() { coordinator.playNext() }

    private static func plainButton(_ symbol: String, size: CGFloat) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.bezelStyle = .shadowlessSquare
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        button.imageScaling = .scaleProportionallyDown
        button.wantsLayer = true
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.7
        button.layer?.shadowRadius = 2.5
        button.layer?.shadowOffset = .zero
        return button
    }
}

final class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { false }
}

final class DisplayOnlyHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
