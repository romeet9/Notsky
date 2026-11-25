import SwiftUI
import AppKit

/// Settings pane: Linear personal API key (stored in the Keychain).
struct LinearSettingsForm: View {
    private var linear = LinearService.shared
    @State private var keyInput: String = ""
    @State private var isConnecting = false

    var body: some View {
        Section("Linear") {
            if linear.hasKey {
                LabeledContent("Status") {
                    Text(linear.connectedName.map { String(localized: "Connected as \($0)") } ?? String(localized: "Connected"))
                        .foregroundStyle(.secondary)
                }
                Button("Disconnect", role: .destructive) {
                    linear.disconnect()
                    keyInput = ""
                }
                .controlSize(.small)
            } else {
                SecureField("Personal API key", text: $keyInput)
                HStack {
                    Link("Get a key", destination: URL(string: "https://linear.app/settings/account/security")!)
                        .font(.caption)
                    Spacer()
                    Button(isConnecting ? LocalizedStringKey("Connecting...") : LocalizedStringKey("Connect")) {
                        isConnecting = true
                        Task {
                            let ok = await linear.connect(key: keyInput)
                            isConnecting = false
                            if ok { keyInput = "" }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                }
                if let error = linear.connectError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }

        Section("About") {
            Text("The Linear card shows open issues assigned to you. Your key is stored in the macOS Keychain and sent only to api.linear.app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
