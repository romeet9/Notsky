import Foundation
import os

/// Shared logger factory so every subsystem logs through os.Logger.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.romeet.notsky.next"
    static let store = Logger(subsystem: subsystem, category: "store")
    static let app = Logger(subsystem: subsystem, category: "app")
    static let export = Logger(subsystem: subsystem, category: "export")
    static let wallpapers = Logger(subsystem: subsystem, category: "wallpapers")
}

/// Locations of Notsky Next's on-disk data. Kept separate from the original Notsky app.
enum AppPaths {
    static let supportFolderName = "Notsky Next"
    static let legacySupportFolderName = "Notsky"
    static let workspaceFileName = "workspace_v1.json"

    static var applicationSupportBase: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    }

    /// Application Support/Notsky Next (created on demand).
    static var supportDirectory: URL {
        let dir = applicationSupportBase.appendingPathComponent(supportFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var workspaceFile: URL {
        supportDirectory.appendingPathComponent(workspaceFileName)
    }

    /// One-time import: if Notsky Next has no workspace yet but the original Notsky does, COPY it.
    /// The original file is never moved or modified.
    static func migrateWorkspaceFromNotskyIfNeeded() {
        let fm = FileManager.default
        let destination = workspaceFile
        guard !fm.fileExists(atPath: destination.path) else { return }
        let source = applicationSupportBase
            .appendingPathComponent(legacySupportFolderName, isDirectory: true)
            .appendingPathComponent(workspaceFileName)
        guard fm.fileExists(atPath: source.path) else { return }
        do {
            try fm.copyItem(at: source, to: destination)
            Log.store.info("Imported workspace copy from Notsky")
        } catch {
            Log.store.error("Could not import Notsky workspace: \(error.localizedDescription, privacy: .public)")
        }
    }
}
