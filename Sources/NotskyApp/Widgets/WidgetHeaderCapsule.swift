import SwiftUI
import AppKit

// MARK: - 4. Reusable Header Capsule Template
public struct WidgetHeaderCapsule<Content: View>: View {
    public var isDark: Bool
    public var baseOpacity: Double
    @ViewBuilder public var content: () -> Content

    public init(isDark: Bool, baseOpacity: Double = 0.70, @ViewBuilder content: @escaping () -> Content) {
        self.isDark = isDark
        self.baseOpacity = baseOpacity
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(WidgetCardDesign.sheetBackgroundColor(isDark: isDark, opacity: baseOpacity), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(WidgetCardDesign.specularBorder(isDark: isDark), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
            .contentShape(Capsule())
    }
}
