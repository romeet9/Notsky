import SwiftUI
import AppKit

/// Settings pane: About. Extracted from SettingsDetailView.
struct AboutSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "note.text")
                    .scaledFont(size: 32, weight: .light)
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notsky Next")
                        .font(.headline)
                    Text("Version \(UpdateManager.shared.currentVersion) (Native macOS)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Minimalist glassmorphic desktop widget notes & focus studio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        
        Section("Software Updates") {
            UpdateStatusRow()
        }
        
        Section("Platform") {
            LabeledContent("Architecture") { Text("Apple Silicon Native") }
            LabeledContent("Frameworks") { Text("SwiftUI & AppKit") }
            LabeledContent("Repository") { Text(verbatim: "github.com/romeet9/Notsky") }
        }
    }
}
