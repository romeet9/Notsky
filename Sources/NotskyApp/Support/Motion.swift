import SwiftUI
import AppKit

/// Reduce Motion support. SwiftUI views read @Environment(\.accessibilityReduceMotion) through the
/// modifiers below; imperative code (withMotion, AppKit window animations) asks NSWorkspace directly.
enum Motion {
    static var reduced: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Animates an NSWindow frame change, or applies it instantly when Reduce Motion is on.
    @MainActor
    static func setFrame(_ window: NSWindow, to frame: NSRect, duration: TimeInterval) {
        if reduced {
            window.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(frame, display: true)
        }
    }
}

/// Drop-in for withAnimation that does nothing when Reduce Motion is on.
@discardableResult
func withMotion<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.reduced ? nil : animation, body)
}

private struct MotionAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: Value
    let fadeWhenReduced: Bool

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? (fadeWhenReduced ? .easeInOut(duration: 0.15) : nil) : animation, value: value)
    }
}

private struct MotionTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}

extension View {
    /// .animation(_:value:) that is removed (or reduced to a short fade) under Reduce Motion.
    func motionAnimation<V: Equatable>(_ animation: Animation?, value: V, fadeWhenReduced: Bool = false) -> some View {
        modifier(MotionAnimationModifier(animation: animation, value: value, fadeWhenReduced: fadeWhenReduced))
    }

    /// .transition(_:) that becomes opacity-only under Reduce Motion.
    func motionTransition(_ transition: AnyTransition) -> some View {
        modifier(MotionTransitionModifier(transition: transition))
    }
}
