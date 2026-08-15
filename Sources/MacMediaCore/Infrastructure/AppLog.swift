import Foundation
import os

public enum AppLog {
    public static let subsystem = "app.macmedia"

    public static let media = Logger(subsystem: subsystem, category: "media")
    public static let engine = Logger(subsystem: subsystem, category: "engine")
    public static let render = Logger(subsystem: subsystem, category: "render")
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let subtitle = Logger(subsystem: subsystem, category: "subtitle")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")

    public static func redactedPath(_ url: URL) -> String {
        url.lastPathComponent
    }
}
