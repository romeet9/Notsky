import SwiftUI
import AppKit

/// Settings pane: Voice push-to-talk shortcut, speech recognition mode and permissions.
struct VoiceSettingsForm: View {
    @Bindable private var voice = VoiceOpenService.shared

    var body: some View {
        Group {
            Section("Push to Talk") {
                Picker("Hold to talk", selection: $voice.hotKeyPreset) {
                    ForEach(VoiceHotKeyPreset.allCases) { preset in
                        Text(verbatim: preset.display).tag(preset)
                    }
                }
                if !voice.isActive {
                    Text("The shortcut works while a Voice card is on your desktop.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !voice.hotKeyRegistered {
                    Text("This shortcut is already used by macOS or another app. Pick another one.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if voice.hotKeyPreset == .controlSpace {
                    Text("⌃Space usually switches input sources. Turn that off in Keyboard Shortcuts › Input Sources to use it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if voice.hotKeyPreset == .optionCommandSpace {
                    Text("⌥⌘Space opens Finder search by default. Turn that off in Keyboard Shortcuts › Spotlight to use it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if voice.hotKeyPreset == .f5 {
                    Text("F5 works without fn only when “Use F1, F2, etc. keys as standard function keys” is on in Keyboard settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Speech Recognition") {
                LabeledContent("Mode") {
                    Text(voice.onDeviceAvailable ? "On this Mac" : "Apple servers (on-device not available for your language)")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Permissions") {
                permissionRow(
                    title: "Microphone",
                    granted: voice.micStatus == .authorized,
                    undetermined: voice.micStatus == .notDetermined,
                    issue: .microphone
                )
                permissionRow(
                    title: "Speech Recognition",
                    granted: voice.speechStatus == .authorized,
                    undetermined: voice.speechStatus == .notDetermined,
                    issue: .speech
                )
            }

            Section("About") {
                Text("Hold the shortcut or the orb and say a command: “add task buy milk”, “new task group Launch”, “add note call Sam”, “next song”. It only controls Notsky Next. Audio is transcribed live and never recorded or stored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { voice.refreshPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            voice.refreshPermissions()
        }
    }

    private func permissionRow(title: LocalizedStringKey, granted: Bool, undetermined: Bool, issue: VoiceOpenService.PermissionIssue) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                if granted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if undetermined {
                    Button("Allow...") { voice.requestPermissions() }
                        .controlSize(.small)
                } else {
                    Text("Denied")
                        .foregroundStyle(.red)
                    Button("Open System Settings") { voice.openPrivacySettings(issue) }
                        .controlSize(.small)
                }
            }
        }
    }
}
