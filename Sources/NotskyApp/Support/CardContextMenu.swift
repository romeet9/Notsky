import SwiftUI

/// Right-click menu for task and freeform note cards (export, header image, pin, folder, delete).
struct CardContextMenu: View {
    @Binding var note: NoteCard
    @Binding var isDownloaded: Bool
    let isDark: Bool
    let onChangeHeaderImage: () -> Void
    let onDelete: () -> Void

    private var folders: [NoteFolder] { WidgetWindowManager.shared.store.folders }

    var body: some View {
        Button(action: downloadImage) {
            RemixLabel("Download 4K Card Image (Downloads)", .downloadLine)
        }

        Button(action: { CardImageExporter.saveCardImageAs(note: note, isDark: isDark) }) {
            RemixLabel("Save 4K Card Image As...", .saveLine)
        }

        Divider()

        Button(action: onChangeHeaderImage) {
            RemixLabel("Change Header Image...", .imageLine)
        }

        Button(action: togglePinned) {
            RemixLabel(note.isPinned ? LocalizedStringKey("Unpin (Wallpaper Canvas Mode)") : LocalizedStringKey("Pin on Top (Floating)"), note.isPinned ? .unpinLine : .pushpinLine)
        }

        Divider()

        Menu("Move to Folder") {
            Button(action: { move(to: nil) }) {
                if note.folderId == nil {
                    RemixLabel("None (Uncategorized)", .checkLine)
                } else {
                    Text("None (Uncategorized)")
                }
            }

            if !folders.isEmpty {
                Divider()
                ForEach(folders) { folder in
                    Button(action: { move(to: folder.id) }) {
                        RemixLabel(verbatim: folder.name, note.folderId == folder.id ? .checkLine : RemixIcon(legacyName: folder.icon))
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive, action: delete) {
            RemixLabel("Delete Note Widget", .deleteBinLine)
        }
    }

    private func downloadImage() {
        CardActions.download(note: note, isDark: isDark, isDownloaded: $isDownloaded)
    }

    private func togglePinned() {
        CardActions.togglePinned($note, haptic: false)
    }

    private func move(to folderId: UUID?) {
        note.folderId = folderId
        SensoryFeedback.buttonClicked()
    }

    private func delete() {
        SensoryFeedback.taskDeleted()
        onDelete()
    }
}

/// Button actions shared by the card toolbar and the card context menu.
@MainActor
enum CardActions {
    /// Saves the 4K card image to Downloads and flashes the toolbar checkmark.
    static func download(note: NoteCard, isDark: Bool, isDownloaded: Binding<Bool>) {
        withMotion(.spring(response: 0.25, dampingFraction: 0.75)) {
            isDownloaded.wrappedValue = true
        }
        CardImageExporter.downloadCardImage(note: note, isDark: isDark)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withMotion(.easeInOut(duration: 0.2)) {
                isDownloaded.wrappedValue = false
            }
        }
    }

    static func togglePinned(_ note: Binding<NoteCard>, haptic: Bool) {
        if haptic { SensoryFeedback.buttonClicked() }
        withMotion(.spring(response: 0.25, dampingFraction: 0.8)) {
            note.wrappedValue.isPinned.toggle()
            WidgetWindowManager.shared.setPinned(note.wrappedValue.isPinned, for: note.wrappedValue.id)
        }
    }
}
