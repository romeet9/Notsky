import SwiftUI

public struct WidgetRootView: View {
    public let noteId: UUID
    @StateObject private var manager = WidgetWindowManager.shared
    @Bindable private var settings = AppSettings.shared
    
    public init(noteId: UUID) {
        self.noteId = noteId
    }
    
    private var safeNoteBinding: Binding<NoteCard>? {
        guard let index = manager.store.notes.firstIndex(where: { $0.id == noteId }) else {
            return nil
        }
        return Binding<NoteCard>(
            get: {
                if let currentIdx = manager.store.notes.firstIndex(where: { $0.id == noteId }) {
                    return manager.store.notes[currentIdx]
                }
                return NoteCard(id: noteId, cardType: .tasks, title: "", headerImagePath: "")
            },
            set: { newValue in
                if let currentIdx = manager.store.notes.firstIndex(where: { $0.id == noteId }) {
                    manager.store.notes[currentIdx] = newValue
                }
            }
        )
    }
    
    public var body: some View {
        if let binding = safeNoteBinding {
            let note = binding.wrappedValue
            ZStack(alignment: .topLeading) {
                switch note.cardType {
                case .finder:
                    FinderCardView(
                        note: binding,
                        onSpawnWidget: {
                            let origin = manager.windowOrigin(for: noteId)
                            manager.spawnNewWidget(near: origin)
                        },
                        onDelete: {
                            manager.closeWidget(noteId: noteId)
                        }
                    )
                    .padding(30)
                case .folders:
                    FoldersCardView(
                        note: binding,
                        onSpawnWidget: {
                            let origin = manager.windowOrigin(for: noteId)
                            manager.spawnNewFoldersWidget(near: origin)
                        },
                        onDelete: {
                            manager.closeWidget(noteId: noteId)
                        }
                    )
                    .padding(30)
                case .notes:
                    FreeformNoteCardView(
                        note: binding,
                        onSpawnWidget: {
                            let origin = manager.windowOrigin(for: noteId)
                            manager.spawnNewFreeformNoteWidget(near: origin)
                        },
                        onDelete: {
                            manager.closeWidget(noteId: noteId)
                        }
                    )
                    .padding(30)
                case .tasks:
                    NoteCardView(
                        note: binding,
                        onSpawnWidget: {
                            let origin = manager.windowOrigin(for: noteId)
                            manager.spawnNewWidget(near: origin)
                        },
                        onDelete: {
                            manager.closeWidget(noteId: noteId)
                        }
                    )
                    .padding(30)
                }
            }
            .frame(
                width: CGFloat(note.width + 60),
                height: CGFloat(note.height + 60),
                alignment: .topLeading
            )
            .preferredColorScheme(settings.preferredColorScheme)
        } else {
            EmptyView()
        }
    }
}

