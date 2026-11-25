import SwiftUI
import AppKit

// MARK: - 3. Widget Card Modifiers
public struct WidgetCardShadowModifier: ViewModifier {
    public var isDark: Bool

    public func body(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(isDark ? 0.08 : 0.04), radius: 6, x: 0, y: 2)
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 12, x: 0, y: 4)
    }
}
