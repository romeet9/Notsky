import SwiftUI
import AppKit
import CoreText

/// Remix Icon (https://remixicon.com, Apache-2.0) glyphs used across the app.
/// rawValue is the glyph's private-use codepoint in remixicon.ttf; case names are the camelCased "ri-" names.
enum RemixIcon: String {
    case notificationBadgeFill = "\u{ef97}"
    case folderFill = "\u{ed61}"
    case folderLine = "\u{ed6a}"
    case sparklingLine = "\u{f36d}"
    /// Not a Remix glyph: the Weft mark drawn as a vector (see WeftMark.swift). Used for Notsky AI.
    case aiMark = "\u{E000}"
    case deleteBinLine = "\u{ec2a}"
    case refreshLine = "\u{f064}"
    case imageLine = "\u{ee4b}"
    case addLine = "\u{ea13}"
    case music2Line = "\u{ef83}"
    case key2Fill = "\u{ee6e}"
    case searchLine = "\u{f0d1}"
    case listUnordered = "\u{eebe}"
    case italic = "\u{ee6b}"
    case alertFill = "\u{ea20}"
    case checkLine = "\u{eb7b}"
    case bold = "\u{ead1}"
    case arrowUpCircleFill = "\u{ea71}"
    case arrowUpLine = "\u{ea76}"
    case checkboxCircleFill = "\u{eb80}"
    case stickyNoteLine = "\u{f19b}"
    case closeLine = "\u{eb99}"
    case voiceprintLine = "\u{f29a}"
    case stackLine = "\u{f181}"
    case editBoxLine = "\u{ec82}"
    case addCircleFill = "\u{ea10}"
    case accountCircleFill = "\u{ea08}"
    case lockFill = "\u{eecd}"
    case folderUnknowFill = "\u{ed7f}"
    case folderAddFill = "\u{ed59}"
    case folderAddLine = "\u{ed5a}"
    case fileSearchLine = "\u{ed05}"
    case fileTextFill = "\u{ed0e}"
    case expandUpDownLine = "\u{f327}"
    case arrowLeftSLine = "\u{ea64}"
    case listCheck = "\u{eeba}"
    case arrowRightUpLine = "\u{ea70}"
    case downloadLine = "\u{ec5a}"
    case windowLine = "\u{f2c6}"
    case saveLine = "\u{f0b3}"
    case pushpinLine = "\u{f039}"
    case pushpinFill = "\u{f038}"
    case unpinLine = "\u{f377}"
    case playFill = "\u{f00a}"
    case pauseFill = "\u{efd7}"
    case skipBackFill = "\u{f13f}"
    case skipForwardFill = "\u{f143}"
    case arrowGoBackFill = "\u{ea57}"
    case settings3Line = "\u{f0e6}"
    case volumeUpLine = "\u{f2a2}"
    case layoutGridLine = "\u{ee90}"
    case paletteLine = "\u{efc5}"
    case timerLine = "\u{f215}"
    case shareBoxLine = "\u{f0f4}"
    case commandLine = "\u{ebb8}"
    case informationLine = "\u{ee59}"
    case fireFill = "\u{ed32}"
    case cupFill = "\u{ec05}"
    case hotelBedFill = "\u{ee38}"
    case lightbulbFill = "\u{eea6}"
    case link = "\u{eeb2}"
    case wifiOffLine = "\u{f2c2}"
    case hourglassLine = "\u{f339}"
    case fileExcel2Line = "\u{ecdd}"
    case fileLine = "\u{eceb}"
    case fileImageLine = "\u{f3c4}"
    case bracesLine = "\u{eae9}"
    case filePdf2Line = "\u{f3c6}"
    case fileTextLine = "\u{ed0f}"

    var glyph: String { rawValue }

    static let fontName = "remixicon"
    private static var didRegister = false

    /// Registers the bundled font for this process. Safe to call repeatedly.
    static func registerFont() {
        guard !didRegister else { return }
        didRegister = true
        guard let url = Bundle.main.url(forResource: "remixicon", withExtension: "ttf", subdirectory: "RemixIcon") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Maps legacy SF Symbol names stored in saved data (folder icons) to Remix icons.
    init(legacyName: String) {
        switch legacyName {
        case "person.crop.circle.fill", "person.crop.circle": self = .accountCircleFill
        case "lightbulb.fill", "lightbulb": self = .lightbulbFill
        case "folder": self = .folderLine
        default: self = .folderFill
        }
    }

    /// Same icon in its filled form when one is bundled (used by folder tiles).
    var filled: RemixIcon { self == .folderLine ? .folderFill : self }
}

/// A Remix icon sized like the SF Symbol it replaces; follows foregroundStyle.
/// Remix glyphs are drawn on a 24-unit grid, so pass the size you want the glyph box to be.
struct RemixImage: View {
    let icon: RemixIcon
    let size: CGFloat
    var accessibilityLabel: LocalizedStringKey?
    var scaled: Bool

    init(_ icon: RemixIcon, size: CGFloat, accessibilityLabel: LocalizedStringKey? = nil) {
        self.icon = icon
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.scaled = false
    }

    /// Multiplies the size by the user's text scale, like .scaledFont(size:).
    init(_ icon: RemixIcon, scaledSize: CGFloat, accessibilityLabel: LocalizedStringKey? = nil) {
        self.icon = icon
        self.size = scaledSize
        self.accessibilityLabel = accessibilityLabel
        self.scaled = true
    }

    var body: some View {
        // Reading the observable singleton re-renders when the text-size slider moves.
        let points = scaled ? size * AppSettings.shared.textScale : size
        let glyph = Group {
            if icon == .aiMark {
                // Remix glyphs sit inside a ~2/24 padding; match that optical size.
                WeftMarkShape().padding(points * 0.1)
            } else {
                Text(icon.glyph).font(.custom(RemixIcon.fontName, fixedSize: points))
            }
        }
        .frame(width: points, height: points)
        if let accessibilityLabel {
            glyph.accessibilityLabel(accessibilityLabel)
        } else {
            glyph.accessibilityHidden(true)
        }
    }
}

extension NSImage {
    /// Draws a Remix glyph into a template image (menus, status items, alerts, drag images).
    static func remix(_ icon: RemixIcon, size: CGFloat, color: NSColor = .black) -> NSImage {
        if icon == .aiMark { return weftMark(size: size, inset: 0.2, color: color) }
        RemixIcon.registerFont()
        let font = NSFont(name: RemixIcon.fontName, size: size) ?? NSFont.systemFont(ofSize: size)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let text = NSAttributedString(string: icon.glyph, attributes: attributes)
        let textSize = text.size()
        let side = ceil(max(size, textSize.width, textSize.height))
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            text.draw(at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = (color == .black)
        return image
    }
}

/// Label with a Remix icon that also works inside Menu / contextMenu / Button menus.
struct RemixLabel: View {
    private let title: Text
    private let icon: RemixIcon
    private let size: CGFloat

    init(_ title: LocalizedStringKey, _ icon: RemixIcon, size: CGFloat = 14) {
        self.title = Text(title)
        self.icon = icon
        self.size = size
    }

    init<S: StringProtocol>(verbatim title: S, _ icon: RemixIcon, size: CGFloat = 14) {
        self.title = Text(verbatim: String(title))
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Label {
            title
        } icon: {
            Image(nsImage: NSImage.remix(icon, size: size))
        }
    }
}
