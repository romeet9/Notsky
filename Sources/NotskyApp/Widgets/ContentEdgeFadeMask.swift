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
