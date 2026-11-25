import SwiftUI
import AppKit

/// Settings pane: Export. Extracted from SettingsDetailView.
struct ExportSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section("Export Quality & Scaling") {
            LabeledContent("Image resolution") {
                Text("4K UHD (2400 × 2400 px @ 4x)")
                    .foregroundStyle(.secondary)
            }
            
            LabeledContent("Save destination") {
                Text("~/Downloads")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
