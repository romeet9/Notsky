import SwiftUI
import AppKit

/// Settings pane: Sensory. Extracted from SettingsDetailView.
struct SensorySettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section("Audio & Tactile Engine") {
            HStack {
                Toggle(isOn: $settings.soundEnabled) {
                    Text("Mechanical click sounds")
                    Text("Tactile synthesized mechanical switch clicks on completing tasks.")
                }
                Spacer()
                Button("Test") { SensoryFeedback.taskCompleted() }
                    .controlSize(.small)
            }
            
            HStack {
                Toggle(isOn: $settings.chimeEnabled) {
                    Text("Completion chime")
                    Text("Harmonic bell chime when a focus countdown timer completes.")
                }
                Spacer()
                Button("Test") { SensoryFeedback.timerFinished() }
                    .controlSize(.small)
            }
            
            HStack {
                Toggle(isOn: $settings.hapticsEnabled) {
                    Text("Trackpad haptic feedback")
                    Text("Tactile Taptic Engine pulse on checking, unchecking, or deleting tasks.")
                }
                Spacer()
                Button("Test") { SensoryFeedback.taskCompleted() }
                    .controlSize(.small)
            }
        }
    }
}
