import SwiftUI
import AppKit

/// The Weft mark (Paper: new-foundations › "Doc / Weft Mark"), used as the Notsky AI icon.
/// Drawn from the original vector path (viewBox 17066.667², only M/H/V/Z commands).
struct WeftMarkShape: Shape {
    private static let viewBox: CGFloat = 17066.667
    /// Absolute points of the outline in viewBox units (y down).
    private static let points: [CGPoint] = {
        let raw: [(Character, CGFloat)] = [
            ("M", 5688.752), ("M", 2188.014), ("H", 7876.827), ("V", 5688.856), ("H", 9189.595), ("V", 2188.014),
            ("H", 11377.649), ("V", -0.04), ("H", 17066.545), ("V", 5688.856), ("H", 14878.47), ("V", 7876.91),
            ("H", 11377.649), ("V", 9189.678), ("H", 14878.47), ("V", 11377.731), ("H", 17066.545), ("V", 17066.627),
            ("H", 11377.649), ("V", 14878.574), ("H", 9189.595), ("V", 11377.731), ("H", 7876.827), ("V", 14878.574),
            ("H", 5688.752), ("V", 17066.627), ("H", -0.122), ("V", 11377.731), ("H", 2187.931), ("V", 9189.678),
            ("H", 5688.752), ("V", 7876.91), ("H", 2187.931), ("V", 5688.856), ("H", -0.122), ("V", -0.04),
            ("H", 5688.752), ("V", 2188.014),
        ]
        var pts: [CGPoint] = []
        var x: CGFloat = raw[0].1
        var y: CGFloat = raw[1].1
        pts.append(CGPoint(x: x, y: y))
        for (cmd, v) in raw.dropFirst(2) {
            if cmd == "H" { x = v } else { y = v }
            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }()

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let s = side / Self.viewBox
        let ox = rect.midX - side / 2, oy = rect.midY - side / 2
        var p = Path()
        p.addLines(Self.points.map { CGPoint(x: ox + $0.x * s, y: oy + $0.y * s) })
        p.closeSubpath()
        return p
    }
}

extension NSImage {
    /// Template image of the Weft mark for menus / AppKit.
    static func weftMark(size: CGFloat, inset: CGFloat = 0.12, color: NSColor = .black) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let r = rect.insetBy(dx: rect.width * inset / 2, dy: rect.height * inset / 2)
            let path = WeftMarkShape().path(in: r).cgPath
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.addPath(path)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
            return true
        }
        image.isTemplate = (color == .black)
        return image
    }
}
