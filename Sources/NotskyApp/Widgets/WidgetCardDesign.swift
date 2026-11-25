import SwiftUI
import AppKit

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
