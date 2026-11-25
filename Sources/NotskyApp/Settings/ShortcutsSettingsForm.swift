import SwiftUI
import AppKit

/// Settings pane: Shortcuts. Extracted from SettingsDetailView.
struct ShortcutsSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
        Section("Keyboard Shortcuts") {
            LabeledContent("Toggle Notes Shelf (Drawer)") {
                HStack(spacing: 6) {
                    ShortcutBadge("⌥ ⌘ D")
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    ShortcutBadge("Double-tap ⌃")
                }
            }
            LabeledContent("Dismiss Notes Shelf") {
                ShortcutBadge("Esc")
            }
            LabeledContent("New Task Group Card") {
                ShortcutBadge("⌘ N")
            }
            LabeledContent("New Freeform Note Card") {
                ShortcutBadge("⌥ ⌘ N")
            }
            LabeledContent("New Voice Card") {
                ShortcutBadge("⌥ ⌘ V")
            }
            LabeledContent("Voice (hold to talk)") {
                ShortcutBadge(LocalizedStringKey(VoiceOpenService.shared.hotKeyPreset.display))
            }
            LabeledContent("Open Notsky Next Settings") {
                ShortcutBadge("⌘ ,")
            }
            LabeledContent("Add Next Task in Row") {
                ShortcutBadge("Return ↵")
            }
            LabeledContent("Quit Notsky Next") {
                ShortcutBadge("⌘ Q")
            }
        }
        
        Section("Widget Controls") {
            LabeledContent("Pin / Wallpaper Canvas Mode") {
                ShortcutBadge("Click [ 📌 ]")
            }
            LabeledContent("Download 4K Master Image") {
                ShortcutBadge("Click [ ⤓ ]")
            }
        }
    }
}
