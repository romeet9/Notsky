import SwiftUI
import AppKit

/// Suggested prompt chips shown before the first Notsky AI message.
struct FinderEmptyState: View {
    let isDark: Bool
    let specularBorderGradient: LinearGradient
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                SuggestedSearchCapsuleButton(
                    text: suggestion,
                    isDark: isDark,
                    specularBorderGradient: specularBorderGradient,
                    action: { onSelect(suggestion) }
                )
            }
        }
        .padding(.vertical, 12)
    }
}

/// Shown instead of the chat until a Groq key is connected.
struct FinderNotConnectedState: View {
    let isDark: Bool
    let specularBorderGradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RemixImage(.aiMark, scaledSize: 18.5)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("Notsky AI")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(isDark ? .white : .black)
            }
            
            Text("Connect a free Groq API key to let Notsky AI manage your cards and find files.")
                .scaledFont(size: 13, weight: .regular)
                .foregroundStyle(isDark ? .white.opacity(0.6) : .black.opacity(0.6))
                .lineLimit(4)
            
            Button {
                SensoryFeedback.buttonClicked()
                SettingsWindowManager.shared.showSettings(item: .ai)
            } label: {
                HStack(spacing: 7) {
                    RemixImage(.key2Fill, scaledSize: 12.5)
                    Text("Add Groq key")
                        .scaledFont(size: 13, weight: .semibold)
                }
                .foregroundStyle(isDark ? .white : .black)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(isDark ? Color(white: 0.18).opacity(0.88) : Color.white.opacity(0.88), in: Capsule())
                .background(.thinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Groq key")
        }
        .padding(.vertical, 12)
    }
}
