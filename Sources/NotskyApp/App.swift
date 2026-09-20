import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImg = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImg
        } else if let iconImg = NSImage(contentsOfFile: "/Applications/Notsky.app/Contents/Resources/AppIcon.icns") {
            NSApp.applicationIconImage = iconImg
        }
        AppSettings.shared.applyDockPolicy()
        WidgetWindowManager.shared.start()
        GlobalHotKeyManager.shared.setup()
    }
}

@main
struct NotskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = WidgetWindowManager.shared
    @StateObject private var pomodoro = PomodoroManager.shared

    var body: some Scene {
        MenuBarExtra {
            Button("Toggle Notes Shelf (Drawer)") {
                DrawerWindowManager.shared.toggleDrawer()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button("New Task Group Card") {
                manager.spawnNewWidget()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Freeform Note Card") {
                manager.spawnNewFreeformNoteWidget()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New AI Finder Card") {
                manager.spawnNewFinderWidget()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Divider()

            Button(action: {
                AppSettings.shared.showInDock.toggle()
            }) {
                HStack {
                    Text("Show in Dock")
                    if AppSettings.shared.showInDock {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button("Settings...") {
                SettingsWindowManager.shared.showSettings(item: .general)
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button("Quit Notsky") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        } label: {
            Image(nsImage: MenuBarIconManager.shared.menuBarIcon)
        }
    }
}
