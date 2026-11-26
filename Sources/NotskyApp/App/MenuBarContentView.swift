import SwiftUI
import AppKit

struct MenuBarContentView: View {
    private var manager = WidgetWindowManager.shared

    var body: some View {
        Button("New Task Group Card") {
            if manager.spawnNewWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("n", modifiers: [.command])

        Button("New Freeform Note Card") {
            if manager.spawnNewFreeformNoteWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("n", modifiers: [.command, .option])

        Button("New Folders Card") {
            if manager.spawnNewFoldersWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("f", modifiers: [.command, .option])

        Button("New Now Playing Card") {
            if manager.spawnNewNowPlayingWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("m", modifiers: [.command, .option])

        Button("New Linear Card") {
            if manager.spawnNewLinearWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("l", modifiers: [.command, .option])

        Button("New Notsky AI Card") {
            if manager.spawnNewFinderWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("a", modifiers: [.command, .option])

        Button("New Voice Card") {
            if manager.spawnNewVoiceOpenWidget() == nil { manager.showNoRoomAlert() }
        }
        .keyboardShortcut("v", modifiers: [.command, .option])

        Divider()

        Button("Clear Workspace") {
            manager.confirmAndClearWorkspace()
        }

        Divider()

        Button("Check for Updates...") {
            SettingsWindowManager.shared.showSettings(item: .about)
            Task {
                await UpdateManager.shared.checkForUpdates()
            }
        }

        Button("Settings...") {
            SettingsWindowManager.shared.showSettings(item: .general)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit Notsky Next") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}
