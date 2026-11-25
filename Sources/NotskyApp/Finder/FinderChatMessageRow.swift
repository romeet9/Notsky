import SwiftUI
import AppKit

/// One user or assistant message (with attached file tiles) in the Finder card chat.
struct FinderChatMessageRow: View {
    let msg: ChatMessage
    let cardWidth: CGFloat
    let isDark: Bool
    let sheetBackgroundColor: Color
    let specularBorderGradient: LinearGradient

    var body: some View {
        if msg.role == "user" {
            HStack {
                Spacer(minLength: 40)
                Text(msg.content)
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(isDark ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isDark ? Color(white: 0.22).opacity(0.85) : Color(white: 0.88).opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.08 : 0.04), radius: 4, y: 1.5)
            }
            .id(msg.id)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !msg.content.isEmpty {
                    Text(msg.content)
                        .scaledFont(size: 14, weight: .regular)
                        .lineSpacing(3)
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                }
                
                if !msg.attachedFiles.isEmpty {
                    LazyVGrid(
                        columns: cardWidth >= 500 ? [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ] : [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(msg.attachedFiles) { file in
                            FinderFileTile(file: file, isDark: isDark, sheetBackgroundColor: sheetBackgroundColor, specularBorderGradient: specularBorderGradient)
                        }
                    }
                }
            }
            .id(msg.id)
        }
    }
}
