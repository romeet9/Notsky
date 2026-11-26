import SwiftUI
import AppKit

/// Placeholder shown when no folders exist yet.
struct FoldersEmptyState: View {
    let isDark: Bool

    var body: some View {
        VStack(spacing: 12) {
            RemixImage(.folderUnknowFill, scaledSize: 41.5)
                .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35))
            
            Text("No Folders Yet")
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(isDark ? .white : .black)
            
            Text("Click the + button above to create your first folder.")
                .scaledFont(size: 12.5, weight: .regular)
                .foregroundStyle(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
