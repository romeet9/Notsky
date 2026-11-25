import SwiftUI
import AppKit

/// Settings pane: Widgets. Extracted from SettingsDetailView.
struct WidgetsSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section("Control Behavior") {
            Toggle(isOn: $settings.autoHideControls) {
                Text("Auto-hide controls on hover")
                Text("Distraction-free mode. Top headers, timers, and action buttons fade in when hovering over a card.")
            }
            
            Toggle(isOn: $settings.highResArtwork) {
                Text("High-resolution artwork")
                Text("Look up sharper album art online for Now Playing. When off, no network requests are made.")
            }
        }
        
        Section("Grid & Placement") {
            Toggle(isOn: $settings.gridSnapping) {
                Text("Snap to desktop grid")
                Text("Automatically align card widgets to desktop grid slots with 24pt spacing.")
            }
            
            LabeledContent("Standard card dimensions") {
                Text("281 × 364 pt")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset all positions")
                    Text("Re-align all open desktop widget cards to top-left grid columns.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset to Grid") {
                    WidgetWindowManager.shared.resetWidgetPositions()
                    SensoryFeedback.buttonClicked()
                }
                .controlSize(.small)
            }
        }
    }
}
