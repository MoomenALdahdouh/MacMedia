import AppKit
import MacMediaCore
import SwiftUI

@MainActor
final class MenuBuilder {
    let history: HistoryManager

    init(history: HistoryManager) {
        self.history = history
    }

    func install() {
        let main = NSMenu()
        main.addItem(appMenu())
        main.addItem(fileMenu())
        main.addItem(playbackMenu())
        main.addItem(videoMenu())
        main.addItem(audioMenu())
        main.addItem(subtitleMenu())
        main.addItem(viewMenu())
        main.addItem(windowMenu())
        main.addItem(helpMenu())
        NSApp.mainMenu = main
    }

    private func appMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "MacMedia")
        menu.addItem(menuItem("About MacMedia", #selector(AppDelegate.showAbout), "", action: #selector(AppDelegate.showAbout)))
        menu.items.last?.target = AppDelegate.shared
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(AppDelegate.showSettings), ",", command: true))
        menu.items.last?.target = AppDelegate.shared
        menu.addItem(.separator())
        menu.addItem(menuItem("Hide MacMedia", nil, "h", command: true, action: #selector(NSApplication.hide(_:))))
        menu.addItem(menuItem("Hide Others", nil, "h", command: true, option: true, action: #selector(NSApplication.hideOtherApplications(_:))))
        menu.addItem(menuItem("Show All", nil, "", action: #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit MacMedia", nil, "q", command: true, action: #selector(NSApplication.terminate(_:))))
        item.submenu = menu
        return item
    }

    private func fileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("File") {
            $0.addItem(targetItem("New Window", #selector(AppDelegate.newPlayerWindow), "n", command: true))
            $0.addItem(.separator())
            $0.addItem(targetItem("Open File…", #selector(AppDelegate.openFile), "o", command: true))
            $0.addItem(targetItem("Open in New Window…", #selector(AppDelegate.openFileInNewWindow), "o", command: true, option: true))
            $0.addItem(targetItem("Open Folder…", #selector(AppDelegate.openFolder), "o", command: true, shift: true))
            $0.addItem(targetItem("Open URL…", #selector(AppDelegate.openURL), "u", command: true))
            $0.addItem(recentMenu())
            $0.addItem(.separator())
            $0.addItem(menuItem("Close", nil, "w", command: true, action: #selector(NSWindow.performClose(_:))))
        }
        return item
    }

    private func playbackMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("Playback") {
            $0.addItem(commandItem("Play/Pause", .playPause))
            $0.addItem(commandItem("Stop", .stop))
            $0.addItem(commandItem("Previous", .playlistPrevious))
            $0.addItem(commandItem("Next", .playlistNext))
            $0.addItem(.separator())
            $0.addItem(commandItem("Seek Forward", .seekForward))
            $0.addItem(commandItem("Seek Backward", .seekBackward))
            $0.addItem(targetItem("Jump to Time…", #selector(AppDelegate.jumpToTime), "g", command: true))
            $0.addItem(.separator())
            let speed = NSMenuItem(title: "Speed", action: nil, keyEquivalent: "")
            speed.submenu = named("Speed") { menu in
                for value in [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0] {
                    let child = NSMenuItem(title: String(format: "%.2gx", value), action: #selector(PlayerWindowController.setSpeedFromMenu(_:)), keyEquivalent: "")
                    child.representedObject = value
                    child.target = nil
                    menu.addItem(child)
                }
            }
            $0.addItem(speed)
            $0.addItem(commandItem("Frame Step Forward", .frameStepForward))
            $0.addItem(commandItem("Frame Step Backward", .frameStepBackward))
        }
        return item
    }

    private func videoMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("Video") {
            let aspect = NSMenuItem(title: "Aspect Ratio", action: nil, keyEquivalent: "")
            aspect.submenu = named("Aspect Ratio") { menu in
                for mode in AspectMode.allCases {
                    let child = NSMenuItem(title: mode.title, action: #selector(PlayerWindowController.setAspectFromMenu(_:)), keyEquivalent: "")
                    child.representedObject = mode.rawValue
                    child.target = nil
                    menu.addItem(child)
                }
            }
            $0.addItem(aspect)
            $0.addItem(commandItem("Screenshot", .screenshot))
            $0.addItem(targetItem("Media Information", #selector(AppDelegate.showMediaInfo), "i", command: true, shift: true))
        }
        return item
    }

    private func audioMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("Audio") {
            $0.addItem(commandItem("Mute", .mute))
            $0.addItem(commandItem("Volume Up", .volumeUp))
            $0.addItem(commandItem("Volume Down", .volumeDown))
            $0.addItem(commandItem("Cycle Audio Track", .cycleAudio))
        }
        return item
    }

    private func subtitleMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("Subtitles") {
            $0.addItem(targetItem("Load Subtitle…", #selector(AppDelegate.loadSubtitle), "s", command: true, shift: true))
            $0.addItem(commandItem("Cycle Subtitle Track", .cycleSubtitle))
            $0.addItem(commandItem("Subtitle Delay +", .subtitleDelayPlus))
            $0.addItem(commandItem("Subtitle Delay −", .subtitleDelayMinus))
        }
        return item
    }

    private func viewMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("View") {
            $0.addItem(commandItem("Fullscreen", .fullscreen))
            $0.addItem(commandItem("Playlist", .togglePlaylist))
            $0.addItem(commandItem("Statistics", .toggleStats))
            $0.addItem(commandItem("Picture in Picture", .pictureInPicture))
            let clean = NSMenuItem(title: "Clean View", action: #selector(PlayerWindowController.toggleCleanView), keyEquivalent: "")
            clean.target = nil
            $0.addItem(clean)
        }
        return item
    }

    private func windowMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("Window") {
            $0.addItem(menuItem("Minimize", nil, "m", command: true, action: #selector(NSWindow.performMiniaturize(_:))))
            $0.addItem(menuItem("Zoom", nil, "", action: #selector(NSWindow.performZoom(_:))))
            $0.addItem(commandItem("Always on Top", .toggleAlwaysOnTop))
        }
        return item
    }

    private func helpMenu() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = named("Help") {
            $0.addItem(targetItem("MacMedia Help", #selector(AppDelegate.showHelpWindow), "?", command: true))
            $0.addItem(.separator())
            $0.addItem(targetItem("Website / GitHub", #selector(AppDelegate.openGitHub), ""))
            $0.addItem(targetItem("Download Latest…", #selector(AppDelegate.openReleases), ""))
            $0.addItem(targetItem("Report Issue…", #selector(AppDelegate.reportIssue), ""))
        }
        return item
    }

    private func recentMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Open Recent")
        for entry in history.all().prefix(15) {
            let child = NSMenuItem(title: entry.title, action: #selector(AppDelegate.openRecent(_:)), keyEquivalent: "")
            child.representedObject = entry.url
            child.target = AppDelegate.shared
            menu.addItem(child)
        }
        if menu.items.isEmpty {
            menu.addItem(NSMenuItem(title: "No Recent Files", action: nil, keyEquivalent: ""))
        }
        item.submenu = menu
        return item
    }

    private func named(_ title: String, build: (NSMenu) -> Void) -> NSMenu {
        let menu = NSMenu(title: title)
        build(menu)
        return menu
    }

    private func commandItem(_ title: String, _ command: PlayerCommand) -> NSMenuItem {
        let chord = KeybindingStore.shared.chord(for: command)
        let item = NSMenuItem(title: title, action: #selector(PlayerWindowController.runCommand(_:)), keyEquivalent: menuKey(chord))
        item.keyEquivalentModifierMask = menuMask(chord)
        item.representedObject = command.rawValue
        item.target = nil
        return item
    }

    private func targetItem(_ title: String, _ selector: Selector, _ key: String, command: Bool = false, shift: Bool = false, option: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        var mask: NSEvent.ModifierFlags = []
        if command { mask.insert(.command) }
        if shift { mask.insert(.shift) }
        if option { mask.insert(.option) }
        item.keyEquivalentModifierMask = mask
        item.target = AppDelegate.shared
        return item
    }

    private func menuItem(_ title: String, _ selector: Selector?, _ key: String, command: Bool = false, option: Bool = false, action: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action ?? selector, keyEquivalent: key)
        var mask: NSEvent.ModifierFlags = []
        if command { mask.insert(.command) }
        if option { mask.insert(.option) }
        item.keyEquivalentModifierMask = mask
        return item
    }

    private func menuKey(_ chord: KeyChord?) -> String {
        guard let chord, chord.key.count == 1 else { return "" }
        return chord.key
    }

    private func menuMask(_ chord: KeyChord?) -> NSEvent.ModifierFlags {
        guard let chord else { return [] }
        var mask: NSEvent.ModifierFlags = []
        if chord.command { mask.insert(.command) }
        if chord.shift { mask.insert(.shift) }
        if chord.option { mask.insert(.option) }
        if chord.control { mask.insert(.control) }
        return mask
    }
}

extension PlayerWindowController {
    @objc func runCommand(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let command = PlayerCommand(rawValue: raw) else { return }
        switch command {
        case .playPause:
            coordinator.togglePlayPause { AppDelegate.shared?.openFile() }
        case .fullscreen: toggleFullscreen()
        case .togglePlaylist: togglePlaylist()
        case .toggleStats: toggleStats()
        case .toggleAlwaysOnTop: toggleAlwaysOnTop()
        case .pictureInPicture: togglePiP()
        default: coordinator.handle(command)
        }
    }

    @objc func setSpeedFromMenu(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            coordinator.engine.setSpeed(value)
        }
    }

    @objc func setAspectFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = AspectMode(rawValue: raw) else { return }
        coordinator.geometry.aspect = mode
        coordinator.engine.setGeometry(coordinator.geometry)
    }

    @objc func openRecent(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            coordinator.open(urls: [url])
        }
    }
}
