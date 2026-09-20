import SwiftUI

public struct WidgetRootView: View {
    public let noteId: UUID
    @StateObject private var manager = WidgetWindowManager.shared
    @Bindable private var settings = AppSettings.shared
    
    public init(noteId: UUID) {
        self.noteId = noteId
    }
    
    public var body: some View {
        if let index = manager.store.notes.firstIndex(where: { $0.id == noteId }) {
            ZStack(alignment: .topLeading) {
                if manager.store.notes[index].cardType == .finder {
                    FinderCardView(
                        note: Binding(
                            get: { manager.store.notes[index] },
                            set: { manager.store.notes[index] = $0 }
                        ),
                        onSpawnWidget: {
                            let origin = manager.windowOrigin(for: noteId)
                            manager.spawnNewWidget(near: origin)
                        },
                        onDelete: {
                            manager.closeWidget(noteId: noteId)
                        }
                    )
                    .padding(30)
                } else if manager.store.notes[index].cardType == .notes {
                    FreeformNoteCardView(
                        note: Binding(
                            get: { manager.store.notes[index] },
                            set: { manager.store.notes[index] = $0 }
                        ),
                        onSpawnWidget: {
                            let origin = manager.windowOrigin(for: noteId)
                            manager.spawnNewFreeformNoteWidget(near: origin)
                        },
                        onDelete: {
                            manager.closeWidget(noteId: noteId)
                        }
                    )
                    .padding(30)
                } else {
                    NoteCardView(
                        note: Binding(
                            get: { manager.store.notes[index] },
                            set: { manager.store.notes[index] = $0 }
                        ),
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
                width: CGFloat(manager.store.notes[index].width + 60),
                height: CGFloat(manager.store.notes[index].height + 60),
                alignment: .topLeading
            )
            .preferredColorScheme(settings.preferredColorScheme)
        } else {
            EmptyView()
        }
    }
}
