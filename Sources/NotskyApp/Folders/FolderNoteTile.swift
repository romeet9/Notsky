import SwiftUI
import AppKit

/// Square tile for a note that lives inside the opened folder.
struct FolderNoteTile: View {
    let card: NoteCard
    let isDark: Bool
    let sheetBackgroundColor: Color
    let specularBorderGradient: LinearGradient
    private var manager = WidgetWindowManager.shared

    var body: some View {
        let isTasks = (card.cardType == .tasks)
        let subtitle: String = {
            if isTasks {
                return String(localized: "\(card.items.count) tasks")
            } else {
                let text = card.pages.first?.content ?? card.noteContent
                let count = text.split { $0.isWhitespace || $0.isNewline }.count
                return String(localized: "\(count) words")
            }
        }()
        
        return Button(action: {
            SensoryFeedback.buttonClicked()
            manager.focusWidget(for: card.id)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Icon + Word/Task count
                HStack(alignment: .center) {
                    RemixImage(isTasks ? .listCheck : .fileTextFill, scaledSize: 20.5)
                        .foregroundStyle(isTasks ? Color.orange.opacity(0.9) : Color.indigo.opacity(0.9))
                    
                    Spacer(minLength: 4)
                    
                    Text(subtitle)
                        .scaledFont(size: 10.5, weight: .medium, design: .rounded)
                        .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                
                Spacer(minLength: 8)
                
                // Bottom Row: Note Title & Snippet Preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title.isEmpty ? (isTasks ? String(localized: "Tasks") : String(localized: "Note")) : card.title)
                        .scaledFont(size: 13, weight: .semibold, design: .default)
                        .tracking(-0.3)
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    
                    let snippet = card.noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !snippet.isEmpty {
                        Text(snippet.replacing("\n", with: " "))
                            .scaledFont(size: 10, weight: .regular)
                            .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 116)
            .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 5, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Bring to Front") {
                manager.focusWidget(for: card.id)
            }
            
            Menu("Move to Folder") {
                Button("None (Uncategorized)") { moveCard(to: nil) }
                Divider()
                ForEach(manager.store.folders) { f in
                    Button(f.name) { moveCard(to: f.id) }
                }
            }
            
            Divider()
            
            Button("Remove from Folder") { moveCard(to: nil) }
        }
        .help("Click to focus this note on desktop")
    }
    private func moveCard(to folderId: UUID?) {
        guard let idx = manager.store.notes.firstIndex(where: { $0.id == card.id }) else { return }
        manager.store.notes[idx].folderId = folderId
    }
}
