import SwiftUI
import AppKit

struct MenuBarContentView: View {
    private var manager = WidgetWindowManager.shared

    var body: some View {
        Button("New Task Group Card") {
            manager.spawnNewWidget()
        }
        .keyboardShortcut("n", modifiers: [.command])

        Button("New Freeform Note Card") {
            manager.spawnNewFreeformNoteWidget()
        }
        .keyboardShortcut("n", modifiers: [.command, .option])

        Button("New Folders Card") {
            manager.spawnNewFoldersWidget()
        }
        .keyboardShortcut("f", modifiers: [.command, .option])

        Button("New Now Playing Card") {
            manager.spawnNewNowPlayingWidget()
        }
        .keyboardShortcut("m", modifiers: [.command, .option])

        Button("New Linear Card") {
            manager.spawnNewLinearWidget()
        }
        .keyboardShortcut("l", modifiers: [.command, .option])

        Button("New Notsky AI Card") {
            manager.spawnNewFinderWidget()
        }
        .keyboardShortcut("a", modifiers: [.command, .option])

        Button("New Voice Card") {
            manager.spawnNewVoiceOpenWidget()
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
