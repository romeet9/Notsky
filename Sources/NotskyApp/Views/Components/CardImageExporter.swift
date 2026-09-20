import SwiftUI
import AppKit

public struct CardExportSnapshotView: View {
    public let note: NoteCard
    public let isDark: Bool
    
    // Universal 1:1 Square 4K Ultra Quality Master Dimensions (2400 × 2400 px @ 4x Retina)
    // Pixel-perfect crisp clarity for LinkedIn, Instagram, and Twitter / X
    private let canvasSize: CGFloat = 600
    
    private var cardWidth: CGFloat { CGFloat(min(320, max(281, note.width))) }
    private var cardHeight: CGFloat { CGFloat(min(420, max(364, note.height))) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    private var contentWidth: CGFloat { max(200, cardWidth - 44) }
    
    private var sheetBackgroundColor: Color {
        let opacity = AppSettings.shared.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }
    
    private var taskTextColor: Color {
        isDark ? Color.white : Color.black
    }
    
    private var completedTaskColor: Color {
        isDark ? Color(white: 0.45) : Color(red: 0.83, green: 0.83, blue: 0.83)
    }
    
    private var dynamicAccentColor: Color {
        ImageLuminanceDetector.dominantAccentColor(at: note.headerImagePath)
    }
    
    private var specularBorderGradient: LinearGradient {
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

    public init(note: NoteCard, isDark: Bool) {
        self.note = note
        self.isDark = isDark
    }

    private var canvasWidth: CGFloat { max(600, cardWidth + 80) }
    private var canvasHeight: CGFloat { max(600, cardHeight + 80) }

    public var body: some View {
        ZStack {
            // 1. Full-Bleed Master Wallpaper Canvas (Crisp, Vibrant, Unblurred Master Background)
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: canvasWidth, height: canvasHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(Color.white.opacity(isDark ? 0.08 : 0.15), lineWidth: 1)
                )

            // 2. Floating NoteCard Widget (Centered in Front of the Wallpaper)
            ZStack(alignment: .top) {
                // Header Image Section (100% Crisp, Sharp, Unblurred)
                HeaderImageView(imagePath: note.headerImagePath)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                // Title Capsule (Inside Crisp Image Section)
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if note.cardType == .notes {
                            Image(systemName: "note.text")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(taskTextColor.opacity(0.65))
                        }
                        let currentTitle: String = (note.cardType == .notes && note.pages.indices.contains(note.activePageIndex))
                            ? note.pages[note.activePageIndex].title
                            : note.title
                        Text(currentTitle)
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundStyle(taskTextColor)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(sheetBackgroundColor, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                    Spacer()
                }
                .frame(width: cardWidth, height: headerHeight)

                // Main Content Area (Only the background below the text is blurred)
                ZStack(alignment: .topLeading) {
                    // Frosted Blurred Wallpaper Underlay directly below the text
                    HeaderImageView(imagePath: note.headerImagePath)
                        .frame(width: cardWidth, height: cardHeight)
                        .offset(y: -headerHeight)
                        .blur(radius: 35)
                        .scaleEffect(1.12)
                        .saturation(1.25)
                        .contrast(1.05)
                        .frame(width: cardWidth, height: sheetHeight)
                        .clipped()

                    // Frosted Glass Tint
                    sheetBackgroundColor

                    if note.cardType == .notes {
                        // Freeform Note Content with rich markdown formatting
                        let currentContent: String = note.pages.indices.contains(note.activePageIndex)
                            ? note.pages[note.activePageIndex].content
                            : note.noteContent
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 22)
                            
                            if let attr = try? AttributedString(markdown: currentContent, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(attr)
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .lineSpacing(4)
                                    .foregroundStyle(taskTextColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            } else {
                                Text(currentContent.isEmpty ? "No notes recorded." : currentContent)
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .lineSpacing(4)
                                    .foregroundStyle(taskTextColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            
                            Spacer(minLength: 22)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        // Task Items List (Sharp, High-Contrast Foreground Text with Equal Top & Bottom Padding)
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 22)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(note.items.enumerated()), id: \.element.id) { index, item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(
                                                item.isCompleted 
                                                    ? completedTaskColor.opacity(isDark ? 0.75 : 0.65)
                                                    : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40))
                                            )
                                            .frame(minWidth: 18, alignment: .leading)
                                            .padding(.top, 1)

                                        Text(item.text)
                                            .font(.system(size: 15, weight: .regular, design: .default))
                                            .tracking(-0.4)
                                            .lineSpacing(2.5)
                                            .foregroundStyle(item.isCompleted ? completedTaskColor : taskTextColor)
                                            .strikethrough(item.isCompleted, color: completedTaskColor.opacity(isDark ? 0.75 : 0.65))
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(width: contentWidth, alignment: .leading)
                                }
                            }
                            
                            Spacer(minLength: 22)
                        }
                        .padding(.horizontal, 22)
                    }
                }
                .frame(width: cardWidth, height: sheetHeight, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                )
                .offset(y: headerHeight)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isDark ? Color.white.opacity(0.16) : Color.white.opacity(0.28), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 36, x: 0, y: 16)
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .frame(width: canvasSize, height: canvasSize)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}

@MainActor
public struct CardImageExporter {
    
    /// Generates the extreme 4K PNG data (2400 × 2400 px) for the note card
    public static func render4KPNGData(note: NoteCard, isDark: Bool) -> (NSImage, Data)? {
        _ = HeaderImageView.getImage(for: note.headerImagePath)
        
        let exportView = CardExportSnapshotView(note: note, isDark: isDark)
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 4.0 // 4K Extreme Master Resolution (2400 × 2400 px)
        
        guard let nsImage = renderer.nsImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return (nsImage, pngData)
    }

    /// Downloads the 4K image directly to ~/Downloads and reveals it in Finder
    @discardableResult
    public static func downloadCardImage(note: NoteCard, isDark: Bool) -> URL? {
        guard let (nsImage, pngData) = render4KPNGData(note: note, isDark: isDark) else {
            return nil
        }
        
        // Sanitize title for filename
        let safeTitle = note.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let cleanName = safeTitle.isEmpty ? "Daily-Focus" : safeTitle
        
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        
        var targetURL = downloadsDirectory.appendingPathComponent("Notsky-\(cleanName).png")
        
        // If file exists, append timestamp so we never overwrite prior exports
        if FileManager.default.fileExists(atPath: targetURL.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            targetURL = downloadsDirectory.appendingPathComponent("Notsky-\(cleanName)-\(stamp).png")
        }
        
        do {
            try pngData.write(to: targetURL, options: .atomic)
            
            // Also copy to clipboard for convenience
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
            pasteboard.setData(pngData, forType: .png)
            
            SensoryFeedback.copied()
            
            // Reveal in Finder
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            return targetURL
        } catch {
            print("Failed to save 4K image: \(error)")
            return nil
        }
    }
    
    /// Opens the native macOS NSSavePanel for custom destination
    public static func saveCardImageAs(note: NoteCard, isDark: Bool) {
        guard let (nsImage, pngData) = render4KPNGData(note: note, isDark: isDark) else { return }
        
        let safeTitle = note.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        let cleanName = safeTitle.isEmpty ? "Daily-Focus" : safeTitle
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Notsky-\(cleanName).png"
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? pngData.write(to: url, options: .atomic)
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
            pasteboard.setData(pngData, forType: .png)
            
            SensoryFeedback.copied()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
