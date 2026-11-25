import SwiftUI
import AppKit

/// Settings pane: General. Extracted from SettingsDetailView.
struct GeneralSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section("Startup & Visibility") {
            Toggle(isOn: $settings.launchAtLogin) {
                Text("Launch at login")
                Text("Start Notsky Next desktop widgets automatically when you log in.")
            }
            
            Toggle(isOn: $settings.showInDock) {
                Text("Show in macOS Dock")
                Text("Keep the Notsky Next icon in the Dock and Command-Tab application switcher.")
            }
        }
        
        Section("Notes Shelf Drawer") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toggle Notes Shelf Drawer")
                    Text("Open the sliding bottom shelf drawer with all note cards.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Toggle Drawer") {
                    DrawerWindowManager.shared.toggleDrawer()
                    SensoryFeedback.buttonClicked()
                }
                .controlSize(.small)
            }
            
            LabeledContent("Global Keyboard Shortcut") {
                HStack(spacing: 6) {
                    ShortcutBadge("⌥ ⌘ D")
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    ShortcutBadge("Double-tap ⌃")
                }
            }
        }
        
        Section("Workspace & Demo Data") {
            Toggle(isOn: $settings.demoDataEnabled) {
                Text("Demo data")
                Text("Fill sample tasks, freeform notes, and AI queries into your desktop cards.")
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear Workspace")
                    Text("Remove all open cards from your desktop workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear All Cards", role: .destructive) {
                    WidgetWindowManager.shared.confirmAndClearWorkspace()
                    SensoryFeedback.buttonClicked()
                }
                .controlSize(.small)
            }
        }
        
        Section("Updates") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notsky Next Updates")
                    Text("Current version: v\(UpdateManager.shared.currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Updates are managed manually in Notsky Next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check for Updates...") {
                    SettingsWindowManager.shared.showSettings(item: .about)
                    Task {
                        await UpdateManager.shared.checkForUpdates()
                    }
                }
                .controlSize(.small)
            }
        }
        
        Section("Window Behavior") {
            Toggle(isOn: $settings.followCursorAcrossDisplays) {
                Text("Follow cursor across displays")
                Text("Open the notes drawer on whichever display the pointer is on. When off, it always opens on the primary display.")
            }
        }
    }
}
