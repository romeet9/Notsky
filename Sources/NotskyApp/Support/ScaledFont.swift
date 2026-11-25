import SwiftUI

/// macOS has no Dynamic Type, so the app exposes its own text-size setting (AppSettings.textScale).
/// Every fixed-size font goes through this modifier so the whole UI follows the slider.
struct ScaledFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        // Reading the observable singleton here re-renders every scaled view when the slider moves.
        content.font(.system(size: size * AppSettings.shared.textScale, weight: weight, design: design))
    }
}

extension View {
    /// Fixed point size multiplied by the user's text scale.
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}
