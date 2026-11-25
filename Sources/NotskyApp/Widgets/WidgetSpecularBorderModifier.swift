import SwiftUI
import AppKit

public struct WidgetSpecularBorderModifier: ViewModifier {
    public var isDark: Bool
    public var cornerRadius: CGFloat
    public var lineWidth: CGFloat

    public init(isDark: Bool, cornerRadius: CGFloat = WidgetCardDesign.cornerRadius, lineWidth: CGFloat = 0.75) {
        self.isDark = isDark
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    public func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(WidgetCardDesign.specularBorder(isDark: isDark), lineWidth: lineWidth)
        )
    }
}

public extension View {
    func widgetCardShadow(isDark: Bool) -> some View {
        self.modifier(WidgetCardShadowModifier(isDark: isDark))
    }

    func widgetSpecularBorder(isDark: Bool, cornerRadius: CGFloat = WidgetCardDesign.cornerRadius, lineWidth: CGFloat = 0.75) -> some View {
        self.modifier(WidgetSpecularBorderModifier(isDark: isDark, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}
