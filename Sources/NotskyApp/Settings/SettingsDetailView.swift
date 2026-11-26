import SwiftUI
import AppKit

// MARK: - Native macOS Settings Detail View
@MainActor
public struct SettingsDetailView: View {
    private var manager = SettingsWindowManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            switch manager.currentItem {
            case .general: GeneralSettingsForm()
            case .sensory: SensorySettingsForm()
            case .widgets: WidgetsSettingsForm()
            case .folders: FoldersSettingsForm()
            case .appearance: AppearanceSettingsForm()
            case .ai: AISettingsForm()
            case .linear: LinearSettingsForm()
            case .voice: VoiceSettingsForm()
            case .focusTimer: FocusTimerSettingsForm()
            case .exportSharing: ExportSettingsForm()
            case .shortcuts: ShortcutsSettingsForm()
            case .about: AboutSettingsForm()
            }
        }
        .formStyle(.grouped)
    }
}
