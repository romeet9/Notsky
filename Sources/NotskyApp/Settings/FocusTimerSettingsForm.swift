import SwiftUI
import AppKit

/// Settings pane: FocusTimer. Extracted from SettingsDetailView.
struct FocusTimerSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section("Session Durations") {
            Picker("Focus session duration", selection: $pomodoro.focusDurationMinutes) {
                ForEach([15, 20, 25, 30, 45, 60], id: \.self) { mins in
                    Text("\(mins) minutes").tag(mins)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Break duration", selection: $pomodoro.breakDurationMinutes) {
                ForEach([5, 10, 15, 20], id: \.self) { mins in
                    Text("\(mins) minutes").tag(mins)
                }
            }
            .pickerStyle(.menu)
        }
        
        Section("Coordinated Timer Behavior") {
            Toggle(isOn: $settings.autoPauseTimers) {
                Text("Auto-pause adjacent timers")
                Text("Ensure only one note timer runs at a time across your desktop canvas.")
            }
        }
    }
}
