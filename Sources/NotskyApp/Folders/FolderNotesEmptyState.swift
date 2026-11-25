import SwiftUI
import AppKit

/// Placeholder shown when the opened folder contains no notes.
struct FolderNotesEmptyState: View {
    let folder: NoteFolder
    let isDark: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .scaledFont(size: 36, weight: .light)
                .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35))
            
            Text("No Notes in \"\(folder.name)\"")
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(isDark ? .white : .black)
            
            Text("Assign a note to this folder using the folder menu on any note card, or click + above to add one.")
                .scaledFont(size: 12.5, weight: .regular)
                .foregroundStyle(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.50))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
