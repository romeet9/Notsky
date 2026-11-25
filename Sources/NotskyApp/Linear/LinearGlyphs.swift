import SwiftUI
import AppKit

// MARK: - Linear-style glyphs
//
// Drawn with shapes only (no fonts), so they render the same everywhere and can be baked into
// NSImages for menu labels and menu items, which on macOS only show Text and Image content.

/// Linear workflow-state glyph: dashed circle (backlog), ring (todo), ring + pie (in progress),
/// check disc (done), cross disc (canceled), dotted disc (triage).
struct LinearStatusGlyph: View {
    let type: String
    let color: Color
    var progress: Double = 0.5
    var size: CGFloat = 14

    var body: some View {
        let line = max(1.25, size * 0.107)
        ZStack {
            switch type {
            case "backlog":
                let circumference = Double.pi * Double(size - line)
                Circle()
                    .stroke(color, style: StrokeStyle(lineWidth: line, dash: [CGFloat(circumference / 14), CGFloat(circumference / 14)]))
                    .padding(line / 2)
            case "unstarted":
                Circle().strokeBorder(color, lineWidth: line)
            case "started":
                Circle().strokeBorder(color, lineWidth: line)
                LinearPieShape(fraction: progress)
                    .fill(color)
                    .padding(line * 2)
            case "completed":
                Circle().fill(color)
                LinearCheckShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.29)
            case "canceled":
                Circle().fill(color)
                LinearCrossShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .padding(size * 0.32)
            case "triage":
                Circle().fill(color)
                Circle().fill(Color.white).padding(size * 0.36)
            default:
                Circle().strokeBorder(color, lineWidth: line)
            }
        }
        .frame(width: size, height: size)
    }
}

struct LinearPieShape: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return p }
        if clamped >= 1 { p.addEllipse(in: rect); return p }
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * clamped), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct LinearCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        return p
    }
}

struct LinearCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

/// Linear priority glyph: urgent orange square with "!", 3/2/1 signal bars, or "no priority" dashes.
struct LinearPriorityGlyph: View {
    let priority: Int
    let color: Color
    var size: CGFloat = 14

    static let urgentColor = Color(linearHex: "#FC7840")

    var body: some View {
        ZStack {
            switch priority {
            case 1:
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Self.urgentColor)
                    .padding(size * 0.04)
                VStack(spacing: size * 0.09) {
                    RoundedRectangle(cornerRadius: size * 0.07).fill(Color.white)
                        .frame(width: size * 0.15, height: size * 0.38)
                    Circle().fill(Color.white)
                        .frame(width: size * 0.16, height: size * 0.16)
                }
            case 2, 3, 4:
                let filled = 5 - priority  // 2 -> 3 bars, 3 -> 2 bars, 4 -> 1 bar
                HStack(alignment: .bottom, spacing: size * 0.11) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: size * 0.06)
                            .fill(color.opacity(i < filled ? 1 : 0.28))
                            .frame(width: size * 0.21, height: size * (0.36 + 0.25 * Double(i)))
                    }
                }
                .frame(width: size, height: size * 0.88, alignment: .bottom)
            default:
                HStack(spacing: size * 0.11) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: size * 0.05)
                            .fill(color.opacity(0.75))
                            .frame(width: size * 0.21, height: size * 0.11)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// Bakes glyphs into non-template NSImages so menus keep their colours. Cached per look and scale.
@MainActor
enum LinearGlyphImage {
    private static var cache: [String: NSImage] = [:]

    private static var scale: CGFloat { NSScreen.main?.backingScaleFactor ?? 2 }

    static func status(type: String, hex: String, progress: Double = 0.5, size: CGFloat = 14) -> NSImage {
        let key = "s|\(type)|\(hex)|\(Int(progress * 100))|\(size)|\(scale)"
        return render(key) {
            LinearStatusGlyph(type: type, color: Color(linearHex: hex), progress: progress, size: size)
        }
    }

    static func priority(_ priority: Int, isDark: Bool, size: CGFloat = 14) -> NSImage {
        let key = "p|\(priority)|\(isDark)|\(size)|\(scale)"
        return render(key) {
            LinearPriorityGlyph(priority: priority, color: isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.58), size: size)
        }
    }

    static func dot(hex: String, size: CGFloat = 8) -> NSImage {
        let key = "d|\(hex)|\(size)|\(scale)"
        return render(key) {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Color(linearHex: hex))
                .frame(width: size, height: size)
        }
    }

    private static func render<V: View>(_ key: String, @ViewBuilder _ content: () -> V) -> NSImage {
        if let cached = cache[key] { return cached }
        let renderer = ImageRenderer(content: content())
        renderer.scale = scale
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 14, height: 14))
        image.isTemplate = false
        cache[key] = image
        return image
    }
}
