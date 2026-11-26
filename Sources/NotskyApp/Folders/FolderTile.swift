import SwiftUI
import AppKit

/// Square folder tile in the Folders card grid (open, rename, delete).
struct FolderTile: View {
    let folder: NoteFolder
    let isDark: Bool
    let sheetBackgroundColor: Color
    let specularBorderGradient: LinearGradient
    @Binding var selectedFolderId: UUID?
    @Binding var renamingFolderId: UUID?
    @Binding var renameText: String
    var isRenameFocused: FocusState<Bool>.Binding
    private var manager = WidgetWindowManager.shared

    var body: some View {
        let notesCount = manager.store.notes(in: folder.id).count
        let isRenaming = (renamingFolderId == folder.id)
        
        return Button(action: {
            SensoryFeedback.buttonClicked()
            withMotion(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedFolderId = folder.id
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Folder Icon + Note Count Badge
                HStack(alignment: .center) {
                    RemixImage(RemixIcon(legacyName: folder.icon).filled, scaledSize: 23)
                        .foregroundStyle(.blue)
                    
                    Spacer(minLength: 4)
                    
                    Text("\(notesCount) notes")
                        .scaledFont(size: 10.5, weight: .medium, design: .rounded)
                        .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                
                Spacer(minLength: 8)
                
                // Bottom Row: Folder Name + Creation Date
                if isRenaming {
                    TextField("Folder Name", text: $renameText)
                        .scaledFont(size: 13, weight: .medium, design: .default)
                        .textFieldStyle(.plain)
                        .focused(isRenameFocused)
                        .onSubmit {
                            manager.store.renameFolder(id: folder.id, newName: renameText)
                            renamingFolderId = nil
                        }
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(folder.name)
                            .scaledFont(size: 13, weight: .semibold, design: .default)
                            .tracking(-0.3)
                            .foregroundStyle(isDark ? Color.white : Color.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        
                        Text(folder.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                            .scaledFont(size: 9.5, weight: .medium, design: .rounded)
                            .foregroundStyle(isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 116)
            .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(.cardMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 5, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Folder") {
                withMotion(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectedFolderId = folder.id
                }
            }
            Button("Rename Folder") {
                renameText = folder.name
                renamingFolderId = folder.id
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.05))
                    isRenameFocused.wrappedValue = true
                }
            }
            Divider()
            Button(role: .destructive, action: {
                manager.store.deleteFolder(id: folder.id)
                SensoryFeedback.taskDeleted()
            }) {
                RemixLabel("Delete Folder", .deleteBinLine)
            }
        }
    }
}
