import SwiftUI
import AppKit

// MARK: - 1. Content Edge Fade Mask (Top & Bottom Linear Gradient Fade)
/// Applies an optical linear fade to the top and bottom edges of scrollable / dynamic card content,
/// preventing harsh clipping against frosted glass toolbars and headers.
public struct ContentEdgeFadeMask: ViewModifier {
    public var topFadeHeight: CGFloat
    public var bottomFadeHeight: CGFloat

    public init(topFadeHeight: CGFloat = 12, bottomFadeHeight: CGFloat = 16) {
        self.topFadeHeight = topFadeHeight
        self.bottomFadeHeight = bottomFadeHeight
    }

    public func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                // Top Edge Linear Fade Out
                if topFadeHeight > 0 {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.0), location: 0.0),
                            .init(color: Color.black.opacity(1.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: topFadeHeight)
                }

                // Fully Opaque Content Body
                Rectangle()
                    .fill(Color.black)

                // Bottom Edge Linear Fade Out
                if bottomFadeHeight > 0 {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(1.0), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bottomFadeHeight)
                }
            }
        )
    }
}

public extension View {
    /// Applies top and bottom optical linear alpha fade masks to content.
    func contentEdgeFade(top: CGFloat = 12, bottom: CGFloat = 16) -> some View {
        self.modifier(ContentEdgeFadeMask(topFadeHeight: top, bottomFadeHeight: bottom))
    }
}

// MARK: - 2. Reusable Widget Card Design System & Metrics
public enum WidgetCardDesign {
    public static let cornerRadius: CGFloat = 40.0
    public static let headerHeight: CGFloat = 53.0
    public static let defaultWidth: CGFloat = 340.0
    public static let defaultHeight: CGFloat = 480.0
    public static let minWidth: CGFloat = 260.0
    public static let minHeight: CGFloat = 220.0
    public static let maxWidth: CGFloat = 800.0
    public static let maxHeight: CGFloat = 1200.0
    public static let tabGap: CGFloat = 24.0

    /// Specular bevel light highlight gradient catching top ambient light (classic macOS 3D optical bevel)
    public static func specularBorder(isDark: Bool) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(isDark ? 0.35 : 0.70), location: 0.0),
                .init(color: Color.white.opacity(isDark ? 0.12 : 0.25), location: 0.5),
                .init(color: Color.white.opacity(isDark ? 0.02 : 0.08), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Standard card frosted glass background color calculation
    public static func sheetBackgroundColor(isDark: Bool, opacity: Double = 0.70) -> Color {
        isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }

    /// Button background color calculation with hover state
    public static func buttonBackgroundColor(isDark: Bool, hovering: Bool, baseOpacity: Double = 0.70) -> Color {
        if isDark {
            return hovering ? Color(white: 0.16).opacity(0.90) : sheetBackgroundColor(isDark: true, opacity: baseOpacity)
        } else {
            return hovering ? Color.white.opacity(0.98) : sheetBackgroundColor(isDark: false, opacity: baseOpacity)
        }
    }
}

// MARK: - 3. Widget Card Modifiers
public struct WidgetCardShadowModifier: ViewModifier {
    public var isDark: Bool

    public func body(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(isDark ? 0.08 : 0.04), radius: 6, x: 0, y: 2)
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 12, x: 0, y: 4)
    }
}

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
