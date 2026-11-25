import SwiftUI
import AppKit

/// Intro copy and suggested-search capsules shown before the first Finder query.
struct FinderEmptyState: View {
    let isDark: Bool
    let specularBorderGradient: LinearGradient
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .scaledFont(size: 16)
                    .foregroundStyle(.red)
                Text("notskyai Local Finder")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(isDark ? .white : .black)
            }
            
            Text("Search, analyze, and query documents across your Mac: PDFs, spreadsheets, Word docs, code, and images.")
                .scaledFont(size: 13, weight: .regular)
                .foregroundStyle(isDark ? .white.opacity(0.6) : .black.opacity(0.6))
                .lineLimit(3)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Searches:")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(isDark ? .white.opacity(0.65) : .black.opacity(0.6))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        SuggestedSearchCapsuleButton(
                            text: suggestion,
                            isDark: isDark,
                            specularBorderGradient: specularBorderGradient,
                            action: { onSelect(suggestion) }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }
}
