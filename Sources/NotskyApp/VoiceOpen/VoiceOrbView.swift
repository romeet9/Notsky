import SwiftUI
import AppKit

enum VoiceOrbMode: Equatable {
    case idle, listening, thinking, success, error
}

/// Apple Intelligence–style orb: blurred gradient blobs orbiting inside a glass sphere.
/// Driven by one TimelineView; speed, swirl and mic level are eased per frame so mode
/// changes never jump. Reduce Motion gets a still orb whose glow only changes opacity.
struct VoiceOrbView: View {
    var mode: VoiceOrbMode
    var diameter: CGFloat
    /// Read every frame (not observed) so mic level doesn't re-render the whole card.
    var level: () -> Double
    /// False while the card is hidden, or idle in the background: the timeline pauses.
    var animating: Bool
    var dimmed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = OrbClock()
    @State private var flash: Double = 0
    @State private var shakes: CGFloat = 0

    static let palette: [Color] = [
        Color(red: 0x2E / 255, green: 0x7B / 255, blue: 0xFF / 255), // blue
        Color(red: 0xB3 / 255, green: 0x4B / 255, blue: 0xFF / 255), // purple
        Color(red: 0xFF / 255, green: 0x4F / 255, blue: 0xA3 / 255), // pink
        Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x3D / 255), // orange
        Color(red: 0x3F / 255, green: 0xE0 / 255, blue: 0xFF / 255)  // cyan
    ]

    private var canvas: CGFloat { diameter * 1.7 }
    private var isDim: Bool { dimmed || mode == .error }

    var body: some View {
        Group {
            if reduceMotion {
                if mode == .listening && animating {
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        orb(OrbFrame(t: 0, phase: 1.3, level: level(), swirl: 0), still: true)
                    }
                } else {
                    orb(OrbFrame(t: 0, phase: 1.3, level: 0, swirl: 0), still: true)
                }
            } else {
                TimelineView(.animation(minimumInterval: nil, paused: !animating)) { context in
                    let frame = clock.advance(
                        to: context.date.timeIntervalSinceReferenceDate,
                        mode: mode,
                        level: mode == .listening ? level() : 0
                    )
                    orb(frame, still: false)
                }
            }
        }
        .frame(width: canvas, height: canvas)
        .overlay {
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: diameter * 0.62))
                .frame(width: diameter * 1.1, height: diameter * 1.1)
                .blendMode(.plusLighter)
                .opacity(flash)
                .allowsHitTesting(false)
        }
        .modifier(OrbShake(animatableData: shakes))
        .saturation(isDim ? 0.35 : 1)
        .opacity(isDim ? 0.6 : 1)
        .motionAnimation(.easeInOut(duration: 0.35), value: isDim, fadeWhenReduced: true)
        .frame(width: diameter, height: diameter)
        .onChange(of: mode, initial: true) { _, new in
            switch new {
            case .success:
                withAnimation(.easeOut(duration: 0.08)) { flash = 0.85 } completion: {
                    withAnimation(.easeOut(duration: 0.7)) { flash = 0 }
                }
            case .error:
                withMotion(.linear(duration: 0.45)) { shakes += 1 }
            default:
                break
            }
        }
    }

    // MARK: - Drawing

    @ViewBuilder
    private func orb(_ f: OrbFrame, still: Bool) -> some View {
        let d = diameter
        let breath = still ? 1 : 1 + 0.03 * sin(f.t * 2 * .pi / 4.2)
        let scale = breath + (still ? 0 : 0.14 * f.level)
        let glowOpacity = 0.42 + 0.4 * f.level + 0.15 * f.swirl + (mode == .listening && still ? 0.15 : 0)

        ZStack {
            // Outer glow
            Circle()
                .fill(AngularGradient(colors: Self.palette + [Self.palette[0]], center: .center, angle: .radians(f.phase * 0.8)))
                .frame(width: d * 0.94, height: d * 0.94)
                .blur(radius: d * 0.15)
                .opacity(glowOpacity)
                .scaleEffect(1.0 + 0.12 * f.level)

            // Sphere
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.42, green: 0.36, blue: 1.0), Color(red: 0.11, green: 0.08, blue: 0.27)],
                        center: .center, startRadius: 0, endRadius: d * 0.5
                    ))
                ForEach(0..<5, id: \.self) { i in
                    blob(i, f, d: d)
                }
                // Thinking: a bright ring that swirls around the inside edge.
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [.white.opacity(0), Self.palette[4], .white, Self.palette[1], .white.opacity(0)], center: .center),
                        lineWidth: d * 0.09
                    )
                    .blur(radius: d * 0.04)
                    .rotationEffect(.radians(f.phase * 2.2))
                    .opacity(0.75 * f.swirl)
                // Inner light that rises with the voice.
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0)], center: .center, startRadius: 0, endRadius: d * 0.32))
                    .opacity(0.25 + 0.6 * f.level)
                    .blendMode(.plusLighter)
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .overlay {
                // Glass highlight
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: d * 0.62, height: d * 0.36)
                    .offset(y: -d * 0.24)
                    .blur(radius: d * 0.02)
                    .blendMode(.plusLighter)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.black.opacity(0.28), lineWidth: d * 0.05)
                    .blur(radius: d * 0.035)
                    .clipShape(Circle())
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.08), .white.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            }
        }
        .scaleEffect(scale)
        .frame(width: canvas, height: canvas)
        .drawingGroup()
    }

    private func blob(_ i: Int, _ f: OrbFrame, d: CGFloat) -> some View {
        let n = Double(i)
        let dir: Double = i.isMultiple(of: 2) ? 1 : -1
        let angle = f.phase * (0.55 + 0.17 * n) * dir + n * 2 * .pi / 5
        let wobble = sin(f.phase * 0.9 + n * 1.3)
        let orbit = d * (0.21 + 0.06 * wobble) * (1 - 0.4 * f.swirl) + d * 0.06 * f.level
        let size = d * (0.6 + 0.1 * sin(f.phase * 1.1 + n * 2.1) + 0.12 * f.level)
        return Circle()
            .fill(Self.palette[i])
            .frame(width: size, height: size)
            .offset(x: cos(angle) * orbit, y: sin(angle) * orbit)
            .blur(radius: d * 0.12)
            .opacity(0.92)
    }
}

struct OrbFrame {
    var t: Double
    var phase: Double
    var level: Double
    var swirl: Double
}

/// Integrates phase with an eased speed so changing modes never makes the blobs jump.
final class OrbClock {
    private var last: TimeInterval = 0
    private var phase: Double = 0
    private var speed: Double = 0.35
    private var level: Double = 0
    private var swirl: Double = 0

    func advance(to t: TimeInterval, mode: VoiceOrbMode, level target: Double) -> OrbFrame {
        let dt = last == 0 ? 0 : min(max(t - last, 0), 0.1)
        last = t
        let targetSpeed: Double
        switch mode {
        case .idle: targetSpeed = 0.35
        case .listening: targetSpeed = 1.1 + 2.4 * target
        case .thinking: targetSpeed = 3.4
        case .success: targetSpeed = 1.6
        case .error: targetSpeed = 0.15
        }
        speed += (targetSpeed - speed) * (1 - exp(-dt * 5))
        level += (target - level) * (1 - exp(-dt * 14))
        swirl += ((mode == .thinking ? 1 : 0) - swirl) * (1 - exp(-dt * 4))
        phase += dt * speed
        return OrbFrame(t: t, phase: phase, level: level, swirl: swirl)
    }
}

/// Horizontal shake: one full cycle per whole-number step of animatableData.
struct OrbShake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 6) * 7, y: 0))
    }
}

/// Reports whether the hosting window is actually on screen (not occluded).
struct WindowVisibilityReader: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> VisibilityView {
        let view = VisibilityView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: VisibilityView, context: Context) {
        nsView.onChange = onChange
    }

    final class VisibilityView: NSView {
        var onChange: ((Bool) -> Void)?
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
            guard let window else { report(false); return }
            token = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.report(nil) }
            }
            report(nil)
        }

        private func report(_ forced: Bool?) {
            let visible = forced ?? (window?.occlusionState.contains(.visible) ?? false)
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.onChange?(visible) }
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}
