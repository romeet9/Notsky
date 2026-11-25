import SwiftUI

public struct DesktopCanvasView: View {
    @Bindable var store: NoteStore
    @State private var useDesktopBackground: Bool = true
    
    public init(store: NoteStore) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            // Background Canvas
            if useDesktopBackground {
                // macOS Sequoia style gradient backdrop
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.38, green: 0.65, blue: 0.88), location: 0.0),
                        .init(color: Color(red: 0.18, green: 0.42, blue: 0.78), location: 0.5),
                        .init(color: Color(red: 0.08, green: 0.22, blue: 0.50), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
            }

            // Note Cards Layout
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 32) {
                    ForEach($store.notes) { $note in
                        if note.cardType == .finder {
                            FinderCardView(
                                note: $note,
                                onDelete: {
                                    withMotion(.easeInOut(duration: 0.25)) {
                                        store.deleteNote(id: note.id)
                                    }
                                }
                            )
                        } else if note.cardType == .folders {
                            FoldersCardView(
                                note: $note,
                                onDelete: {
                                    withMotion(.easeInOut(duration: 0.25)) {
                                        store.deleteNote(id: note.id)
                                    }
                                }
                            )
                        } else if note.cardType == .notes {
                            FreeformNoteCardView(
                                note: $note,
                                onDelete: {
                                    withMotion(.easeInOut(duration: 0.25)) {
                                        store.deleteNote(id: note.id)
                                    }
                                }
                            )
                        } else {
                            NoteCardView(
                                note: $note,
                                onDelete: {
                                    withMotion(.easeInOut(duration: 0.25)) {
                                        store.deleteNote(id: note.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(48)
                .frame(minWidth: 1000, minHeight: 650, alignment: .leading)
            }

            // Floating Controls Bar (Bottom)
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        withMotion(.spring(duration: 0.35)) {
                            store.addNote()
                        }
                    }) {
                        Label("New Task Group", systemImage: "plus.circle.fill")
                            .scaledFont(size: 13, weight: .medium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5) }
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)

                    Button(action: {
                        withMotion(.spring(duration: 0.35)) {
                            store.addFreeformNote()
                        }
                    }) {
                        Label("New Notes Card", systemImage: "doc.text.fill")
                            .scaledFont(size: 13, weight: .medium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5) }
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)

                    Button(action: {
                        withMotion(.spring(duration: 0.35)) {
                            store.addFoldersNote()
                        }
                    }) {
                        Label("New Folders", systemImage: "folder.fill")
                            .scaledFont(size: 13, weight: .medium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5) }
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)

                    Button(action: {
                        withMotion {
                            useDesktopBackground.toggle()
                        }
                    }) {
                        Label(useDesktopBackground ? LocalizedStringKey("Desktop Wallpaper") : LocalizedStringKey("System Background"), systemImage: "macwindow")
                            .scaledFont(size: 13, weight: .medium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5) }
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
    }
}
