import SwiftUI
import AppKit

// MARK: - White Frosted Glass Suggested Search Button (Matching Open Finder & Labels)

struct SuggestedSearchCapsuleButton: View {
    let text: String
    let isDark: Bool
    let specularBorderGradient: LinearGradient
    let action: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: {
            SensoryFeedback.buttonClicked()
            action()
        }) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.7))
                
                Text(text)
                    .scaledFont(size: 12.5, weight: .medium)
                    .foregroundStyle(isDark ? .white.opacity(0.95) : .black.opacity(0.9))
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                isDark ? Color.white.opacity(isHovering ? 0.24 : 0.16) : Color(white: 0.88).opacity(isHovering ? 0.96 : 0.85),
                in: Capsule()
            )
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 6, x: 0, y: 1.5)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .motionAnimation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
