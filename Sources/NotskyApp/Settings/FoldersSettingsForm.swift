import SwiftUI
import AppKit

/// Settings pane: Folders. Extracted from SettingsDetailView.
struct FoldersSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared
    @State private var newFolderName: String = ""
    @State private var editingFolderId: UUID? = nil
    @State private var editingFolderName: String = ""

    var body: some View {
        let store = WidgetWindowManager.shared.store
        
        Section("Folders Desktop Widget") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Folders Widget on Desktop")
                        .font(.body)
                    Text("Spawn a dedicated widget showing all your folders in the frosted glass file grid.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Spawn Folders Widget") {
                    WidgetWindowManager.shared.spawnNewFoldersWidget()
                    SensoryFeedback.widgetSpawned()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        
        Section("Manage Folders") {
            if store.folders.isEmpty {
                Text("No folders created yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.folders) { folder in
                    let notesCount = store.notes(in: folder.id).count
                    HStack(spacing: 12) {
                        RemixImage(RemixIcon(legacyName: folder.icon), scaledSize: 18.5)
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        
                        if editingFolderId == folder.id {
                            TextField("Folder Name", text: $editingFolderName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    let trimmed = editingFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        store.renameFolder(id: folder.id, newName: trimmed)
                                    }
                                    editingFolderId = nil
                                }
                            
                            Button("Save") {
                                let trimmed = editingFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    store.renameFolder(id: folder.id, newName: trimmed)
                                }
                                editingFolderId = nil
                            }
                            .controlSize(.small)
                        } else {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(folder.name)
                                    .scaledFont(size: 13, weight: .medium)
                                Text("\(notesCount) notes")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Rename") {
                                editingFolderId = folder.id
                                editingFolderName = folder.name
                            }
                            .controlSize(.small)
                            
                            Button(role: .destructive) {
                                store.deleteFolder(id: folder.id)
                                SensoryFeedback.taskDeleted()
                            } label: {
                                RemixImage(.deleteBinLine, size: 14)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete Folder")
                            .accessibilityLabel("Delete Folder")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            // Add New Folder Row
            HStack(spacing: 10) {
                RemixImage(.folderAddLine, scaledSize: 17.5)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                TextField("New folder name...", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            store.createFolder(name: trimmed)
                            newFolderName = ""
                            SensoryFeedback.taskAdded()
                        }
                    }
                
                Button("Add Folder") {
                    let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        store.createFolder(name: trimmed)
                        newFolderName = ""
                        SensoryFeedback.taskAdded()
                    }
                }
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        
        Section("How Folders Work") {
            VStack(alignment: .leading, spacing: 6) {
                Text("• **Assigning Notes:** Use the folder button inside any task card or freeform note card to assign it to a folder.")
                Text("• **Viewing Notes:** Click any folder inside the Folders widget to view its notes in the square card grid.")
                Text("• **Shortcuts:** Press **⌥ ⌘ F** or use the menu bar icon to quickly spawn the Folders widget on desktop.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
