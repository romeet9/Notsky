import SwiftUI

/// Bottom-left "assign to folder" capsule with its popovers, shared by task and freeform note cards.
struct CardFolderPicker: View {
    @Binding var note: NoteCard

    @State private var showFolderPopover = false
    @State private var showNewFolderDialog = false
    @State private var newFolderNameInput = ""

    var body: some View {
            Button(action: {
                SensoryFeedback.buttonClicked()
                showFolderPopover.toggle()
            }) {
                HStack(spacing: 6) {
                    let assignedFolder = WidgetWindowManager.shared.store.folder(for: note.folderId)
                    Image(systemName: "folder.fill")
                        .scaledFont(size: 11.5, weight: .semibold)
                        .foregroundStyle(.black)
                    
                    Text(assignedFolder?.name ?? String(localized: "Folder"))
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .scaledFont(size: 8, weight: .bold)
                        .foregroundStyle(Color.black.opacity(0.65))
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.white, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFolderPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Folder")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                    
                    Button(action: {
                        select(folderId: nil)
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .scaledFont(size: 11)
                                .foregroundStyle(.secondary)
                            Text("None (Uncategorized)")
                                .scaledFont(size: 12)
                                .foregroundStyle(.primary)
                            Spacer()
                            if note.folderId == nil {
                                Image(systemName: "checkmark")
                                    .scaledFont(size: 11, weight: .bold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if !WidgetWindowManager.shared.store.folders.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                        
                        ForEach(WidgetWindowManager.shared.store.folders) { folder in
                            Button(action: {
                                select(folderId: folder.id)
                            }) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .scaledFont(size: 11)
                                        .foregroundStyle(Color.accentColor)
                                    Text(folder.name)
                                        .scaledFont(size: 12)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if note.folderId == folder.id {
                                        Image(systemName: "checkmark")
                                            .scaledFont(size: 11, weight: .bold)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    Button(action: {
                        showFolderPopover = false
                        showNewFolderDialog = true
                        newFolderNameInput = ""
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .scaledFont(size: 11.5)
                                .foregroundStyle(Color.accentColor)
                            Text("New Folder...")
                                .scaledFont(size: 12, weight: .medium)
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .frame(width: 190)
            }
            .popover(isPresented: $showNewFolderDialog) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create New Folder")
                        .scaledFont(size: 12, weight: .bold)
                    
                    TextField("Folder Name", text: $newFolderNameInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit {
                            createFolderAndAssign()
                        }
                    
                    HStack {
                        Button("Cancel") {
                            showNewFolderDialog = false
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Create") {
                            createFolderAndAssign()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(14)
            }
            .help("Assign to Folder")
    }

    private func select(folderId: UUID?) {
        note.folderId = folderId
        showFolderPopover = false
        SensoryFeedback.buttonClicked()
    }

    private func createFolderAndAssign() {
        let created = WidgetWindowManager.shared.store.createFolder(name: newFolderNameInput)
        note.folderId = created.id
        showNewFolderDialog = false
        SensoryFeedback.taskAdded()
    }
}
