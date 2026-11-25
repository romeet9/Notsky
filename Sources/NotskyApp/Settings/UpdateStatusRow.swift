import SwiftUI

/// Software-update status row shown in Settings > About.
struct UpdateStatusRow: View {
    private var updater = UpdateManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GitHub Releases")
                        .font(.body)
                    
                    switch updater.status {
                    case .idle:
                        if let date = updater.lastCheckedDate {
                            Text("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Check for the latest features, fixes, and performance updates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .checking:
                        Text("Checking GitHub Releases for updates...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .upToDate:
                        Text("Notsky Next is up to date (Version \(updater.currentVersion)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .updateAvailable(let ver, _, _):
                        Text("New version \(ver) is available!")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case .downloading:
                        Text("Downloading latest release from GitHub...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .installing:
                        Text("Installing update and preparing to relaunch...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .error(let msg):
                        Text("Update error: \(msg)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    case .managedManually:
                        Text("Updates are managed manually in Notsky Next")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                switch updater.status {
                case .idle, .upToDate, .error, .managedManually:
                    Button("Check for Updates") {
                        Task {
                            await updater.checkForUpdates()
                        }
                    }
                    .controlSize(.small)
                case .checking:
                    ProgressView()
                        .controlSize(.small)
                case .updateAvailable(_, _, let downloadUrl):
                    Button("Install Update") {
                        Task {
                            await updater.downloadAndInstall(url: downloadUrl)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                case .downloading, .installing:
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            if case .updateAvailable(let ver, let notes, _) = updater.status, !notes.isEmpty {
                DisclosureGroup("Release Notes (\(ver))") {
                    ScrollView {
                        Text(notes)
                            .scaledFont(size: 11.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .frame(maxHeight: 120)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
