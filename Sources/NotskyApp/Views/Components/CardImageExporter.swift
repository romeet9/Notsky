import SwiftUI
import AppKit

public struct CardExportSnapshotView: View {
    public let note: NoteCard
    public let isDark: Bool
    
    // Universal 1:1 Square 4K Ultra Quality Master Dimensions (2400 × 2400 px @ 4x Retina)
    private let canvasSize: CGFloat = 600
    
    private var isNotesType: Bool { note.cardType == .notes }
    private var isFinderType: Bool { note.cardType == .finder }
    
    private var cardWidth: CGFloat {
        if isFinderType {
            return CGFloat(max(360, min(586, note.width > 281 ? note.width : 360)))
        } else if isNotesType {
            return CGFloat(max(350, min(586, note.width > 281 ? note.width : 360)))
        } else {
            return CGFloat(max(300, min(586, note.width)))
        }
    }
    
    private var cardHeight: CGFloat {
        if isFinderType {
            return CGFloat(max(460, min(752, note.height > 364 ? note.height : 460)))
        } else if isNotesType {
            return CGFloat(max(440, min(752, note.height > 364 ? note.height : 450)))
        } else {
            return CGFloat(max(440, min(752, note.height > 364 ? note.height : 450)))
        }
    }
    
    private let headerHeight: CGFloat = 54
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    private var contentWidth: CGFloat { max(200, cardWidth - 44) }
    private var toolbarWidth: CGFloat { max(220, cardWidth - 28) }
    
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
    
    private var buttonIconColor: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.75)
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
    
    private var timerHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.40)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var timeString: String {
        let m = note.timeRemaining / 60
        let s = note.timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    public init(note: NoteCard, isDark: Bool) {
        self.note = note
        self.isDark = isDark
    }

    public var body: some View {
        ZStack {
            // 1. Full-Bleed Master Wallpaper Canvas (Crisp, Vibrant, Unblurred Master Background)
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: canvasSize, height: canvasSize)
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

                // Top Header Title / Tabs Bar (Inside Header Region)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if isFinderType {
                        // notskyai Title & Status Capsules
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.red)
                                Text("notskyai")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundStyle(taskTextColor)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                            
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("ready")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(taskTextColor.opacity(0.85))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                        }
                    } else if isNotesType {
                        // Multi-Tab bar for Notes
                        HStack(spacing: 6) {
                            let pages = note.pages.isEmpty ? [NotePage(title: note.title.isEmpty ? "Quick Note" : note.title, content: note.noteContent)] : note.pages
                            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                                let isActive = (note.activePageIndex == index)
                                HStack(spacing: 4) {
                                    Text(page.title.isEmpty ? "Note \(index + 1)" : page.title)
                                        .font(.system(size: 12.5, weight: isActive ? .semibold : .medium, design: .default))
                                        .foregroundStyle(isActive ? taskTextColor : taskTextColor.opacity(0.65))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, isActive ? 12 : 10)
                                .frame(height: 34)
                                .background(isActive ? sheetBackgroundColor : sheetBackgroundColor.opacity(0.40), in: Capsule())
                                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                                .shadow(color: Color.black.opacity(isActive ? (isDark ? 0.04 : 0.02) : 0), radius: 3, x: 0, y: 1)
                            }
                            
                            // + Tab Button
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(buttonIconColor)
                                .frame(width: 34, height: 34)
                                .background(sheetBackgroundColor, in: Circle())
                                .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                        }
                    } else {
                        // Title Capsule & Timer Pill for Tasks
                        HStack(spacing: 8) {
                            Text(note.title)
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(taskTextColor)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(sheetBackgroundColor, in: Capsule())
                                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                                .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                            
                            // Pomodoro Timer Pill
                            HStack(spacing: 5) {
                                Image(systemName: note.isTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(note.isTimerRunning ? Color.orange : buttonIconColor)
                                
                                Text(timeString)
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(note.isTimerRunning ? (isDark ? Color.white : Color.orange) : taskTextColor.opacity(0.88))
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay(Capsule().strokeBorder(note.isTimerRunning ? timerHighlightGradient : specularBorderGradient, lineWidth: 0.75))
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)

                // Main Frosted Glass Content Sheet
                ZStack(alignment: .top) {
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

                    // Complete Sheet Content: Top Toolbar + Body + Bottom Toolbar
                    VStack(spacing: 0) {
                        // 1. Top Toolbar with Buttons Visible
                        HStack {
                            if isFinderType {
                                // Add Button (+ Circle)
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(buttonIconColor)
                                    .frame(width: 36, height: 36)
                                    .background(sheetBackgroundColor, in: Circle())
                                    .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            } else if isNotesType {
                                // Formatting Capsule (Bold, Italic, Bullets)
                                HStack(spacing: 12) {
                                    Image(systemName: "bold")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(buttonIconColor)
                                    Image(systemName: "italic")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(buttonIconColor)
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(buttonIconColor)
                                }
                                .padding(.horizontal, 13)
                                .frame(height: 36)
                                .background(sheetBackgroundColor, in: Capsule())
                                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                                .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            } else {
                                // Add Button (+ Circle)
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(buttonIconColor)
                                    .frame(width: 36, height: 36)
                                    .background(sheetBackgroundColor, in: Circle())
                                    .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            }

                            Spacer()

                            // Right Action Capsule: Download, Pin, Cycle, Photo, Trash
                            HStack(spacing: 10) {
                                if isFinderType {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(buttonIconColor)
                                } else {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(buttonIconColor)
                                }
                                Image(systemName: note.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(note.isPinned ? Color.orange : buttonIconColor)
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(buttonIconColor)
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(buttonIconColor)
                                Image(systemName: "trash")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(buttonIconColor)
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 36)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                        }
                        .frame(width: toolbarWidth)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                        // 2. Body Content
                        if isFinderType {
                            VStack(alignment: .leading, spacing: 10) {
                                // User Query Bubble
                                HStack {
                                    Spacer()
                                    Text("Find design tokens & icons from yesterday")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                
                                // File Match Cards
                                VStack(spacing: 5) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.red)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Tokens.swift")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(taskTextColor)
                                            Text("2.4 KB · Modified Yesterday")
                                                .font(.system(size: 10))
                                                .foregroundStyle(taskTextColor.opacity(0.50))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(sheetBackgroundColor.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(specularBorderGradient, lineWidth: 0.5))

                                    HStack(spacing: 8) {
                                        Image(systemName: "app.badge.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.orange)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("AppIcon.icns")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(taskTextColor)
                                            Text("1.2 MB · Modified Today")
                                                .font(.system(size: 10))
                                                .foregroundStyle(taskTextColor.opacity(0.50))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(sheetBackgroundColor.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(specularBorderGradient, lineWidth: 0.5))
                                }

                                // AI Assistant Synthesis
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.red)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.top, 2)
                                    Text("Extracted liquid glass tokens and verified 1024×1024 Retina icon layers.")
                                        .font(.system(size: 11.5, weight: .regular))
                                        .foregroundStyle(taskTextColor)
                                        .lineSpacing(2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(sheetBackgroundColor.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 4)
                            .frame(maxHeight: .infinity)
                        } else if isNotesType {
                            let currentContent: String = note.pages.indices.contains(note.activePageIndex)
                                ? note.pages[note.activePageIndex].content
                                : note.noteContent
                            VStack(alignment: .leading, spacing: 0) {
                                if let attr = try? AttributedString(markdown: currentContent, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                    Text(attr)
                                        .font(.system(size: 13.5, weight: .regular, design: .default))
                                        .lineSpacing(3.5)
                                        .foregroundStyle(taskTextColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                } else {
                                    Text(currentContent.isEmpty ? "No notes recorded." : currentContent)
                                        .font(.system(size: 13.5, weight: .regular, design: .default))
                                        .lineSpacing(3.5)
                                        .foregroundStyle(taskTextColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .frame(maxHeight: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(note.items.enumerated()), id: \.element.id) { index, item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(
                                                item.isCompleted 
                                                    ? completedTaskColor.opacity(isDark ? 0.75 : 0.65)
                                                    : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40))
                                            )
                                            .frame(minWidth: 16, alignment: .leading)
                                            .padding(.top, 1)

                                        Text(item.text)
                                            .font(.system(size: 13.5, weight: .regular, design: .default))
                                            .tracking(-0.3)
                                            .lineSpacing(2)
                                            .foregroundStyle(item.isCompleted ? completedTaskColor : taskTextColor)
                                            .strikethrough(item.isCompleted, color: completedTaskColor.opacity(isDark ? 0.75 : 0.65))
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(width: contentWidth, alignment: .leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .frame(maxHeight: .infinity)
                        }

                        // 3. Bottom Toolbar / Search Bar
                        if isFinderType {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(taskTextColor.opacity(0.50))
                                Text("Ask notskyai or search files...")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(taskTextColor.opacity(0.40))
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.red)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .padding(.top, 4)
                        } else {
                            HStack {
                                if isNotesType {
                                    let plainText = (note.pages.indices.contains(note.activePageIndex) ? note.pages[note.activePageIndex].content : note.noteContent)
                                        .replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
                                    let words = plainText.split { $0.isWhitespace || $0.isNewline }.count
                                    let chars = plainText.count
                                    Text("\(words) words · \(chars) chars")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(taskTextColor.opacity(0.50))
                                        .padding(.leading, 18)
                                }
                                Spacer()
                                Text("Add Group")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundStyle(buttonIconColor)
                                    .padding(.horizontal, 13)
                                    .frame(height: 32)
                                    .background(sheetBackgroundColor, in: Capsule())
                                    .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                                    .padding(.trailing, 16)
                            }
                            .frame(width: cardWidth)
                            .padding(.bottom, 16)
                            .padding(.top, 4)
                        }
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

            // 3. Top-Right Corner Branding Logo (Icon Only, No Text, No Background Border, Prominent Size)
            VStack {
                HStack {
                    Spacer()
                    if let icon = brandingIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
                            .shadow(color: Color.black.opacity(0.40), radius: 6, x: 0, y: 2.5)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.red)
                            .shadow(color: Color.black.opacity(0.40), radius: 6, x: 0, y: 2.5)
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
                
                Spacer()
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    private var brandingIcon: NSImage? {
        let possiblePaths = [
            Bundle.main.path(forResource: "AppIcon", ofType: "png"),
            Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
            "/Applications/Notsky.app/Contents/Resources/AppIcon.icns",
            "/Users/romeet/.gemini/antigravity/scratch/NotskyApp/docs/screenshots/AppIcon.png",
            Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        ]
        for path in possiblePaths.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        if let appIcon = NSApp.applicationIconImage, appIcon.isValid {
            return appIcon
        }
        return nil
    }
}

@MainActor
public struct CardImageExporter {
    
    /// Generates the extreme 4K PNG data (2400 × 2400 px) for the note card
    public static func render4KPNGData(note: NoteCard, isDark: Bool) -> (NSImage, Data)? {
        autoreleasepool {
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
