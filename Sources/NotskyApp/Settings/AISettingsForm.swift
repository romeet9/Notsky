import SwiftUI
import AppKit

/// Settings pane: Groq API key (stored in the Keychain), model choice and file-search permission for Notsky AI.
struct AISettingsForm: View {
    @Bindable private var account = GroqAccount.shared
    @State private var keyInput: String = ""
    @State private var isConnecting = false

    private var modelBinding: Binding<String> {
        Binding(
            get: { account.activeModel },
            set: { account.selectedModel = $0 }
        )
    }

    var body: some View {
        Section("Groq") {
            if account.hasKey {
                LabeledContent("Status") {
                    RemixLabel("Connected", .checkboxCircleFill)
                        .foregroundStyle(.green)
                }
                if account.models.isEmpty {
                    LabeledContent("Model") {
                        if account.isLoadingModels {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Load models") { Task { await account.refreshModels() } }
                                .controlSize(.small)
                        }
                    }
                } else {
                    Picker("Model", selection: modelBinding) {
                        ForEach(account.models, id: \.self) { id in
                            Text(verbatim: id).tag(id)
                        }
                    }
                }
                Button("Disconnect", role: .destructive) {
                    account.disconnect()
                    keyInput = ""
                }
                .controlSize(.small)
            } else {
                SecureField("Groq API key", text: $keyInput)
                    .accessibilityLabel(Text("Groq API key"))
                HStack {
                    Link("Get a key", destination: URL(string: "https://console.groq.com/keys")!)
                        .font(.caption)
                    Spacer()
                    Button(isConnecting ? LocalizedStringKey("Connecting...") : LocalizedStringKey("Connect")) {
                        isConnecting = true
                        Task {
                            let ok = await account.connect(key: keyInput)
                            isConnecting = false
                            if ok { keyInput = "" }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                }
                if let error = account.connectError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }

        Section("Privacy") {
            Toggle("Let AI search file names on this Mac", isOn: $account.searchFilesEnabled)
            Text("When on, Notsky AI can look up file and folder names with Spotlight and open them for you. File contents are never read or sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("About") {
            Text("Notsky AI powers the AI card and the Voice card. It can add, edit, pin and delete cards, tasks and notes, control music and find files. Deleting anything asks you to confirm first. Your key is stored in the macOS Keychain and sent only to api.groq.com, together with your messages and a short summary of your cards.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            if account.hasKey { await account.ensureModelsLoaded() }
        }
    }
}
