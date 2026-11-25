import SwiftUI
import AppKit

public struct CardExportSnapshotView: View {
    public let note: NoteCard
    public let isDark: Bool
    
    // Universal 1:1 Square 4K Ultra Quality Master Dimensions (2400 × 2400 px @ 4x Retina)
    private let canvasSize: CGFloat = 600
    
    private var isNotesType: Bool { note.cardType == .notes }
    private var isFinderType: Bool { note.cardType == .finder }
    private var isFoldersType: Bool { note.cardType == .folders }
    
    private var cardWidth: CGFloat {
        if isFinderType || isFoldersType {
            return CGFloat(max(360, min(586, note.width > 281 ? note.width : 360)))
        } else if isNotesType {
            return CGFloat(max(350, min(586, note.width > 281 ? note.width : 360)))
        } else {
            return CGFloat(max(300, min(586, note.width)))
        }
    }
    
    private var cardHeight: CGFloat {
        if isFinderType || isFoldersType {
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
        note.timeRemaining.minutesSecondsString
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
                                    .scaledFont(size: 11, weight: .semibold)
                                    .foregroundStyle(Color.red)
                                Text("notskyai")
                                    .scaledFont(size: 13, weight: .semibold, design: .default)
                                    .foregroundStyle(taskTextColor)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                            
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("ready")
                                    .scaledFont(size: 12, weight: .medium, design: .rounded)
                                    .foregroundStyle(taskTextColor.opacity(0.85))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                        }
                    } else if isFoldersType {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .scaledFont(size: 12, weight: .semibold)
                                    .foregroundStyle(Color.blue)
                                Text("Folders")
                                    .scaledFont(size: 13, weight: .semibold, design: .default)
                                    .foregroundStyle(taskTextColor)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                            
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("3 folders")
                                    .scaledFont(size: 12, weight: .medium, design: .rounded)
                                    .foregroundStyle(taskTextColor.opacity(0.85))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                        }
                    } else if isNotesType {
                        // Multi-Tab bar for Notes
                        HStack(spacing: 6) {
                            let pages = note.pages.isEmpty ? [NotePage(title: note.title.isEmpty ? String(localized: "Quick Note") : note.title, content: note.noteContent)] : note.pages
                            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                                let isActive = (note.activePageIndex == index)
                                HStack(spacing: 4) {
                                    Text(page.title.isEmpty ? String(localized: "Note \(index + 1)") : page.title)
                                        .scaledFont(size: 12.5, weight: isActive ? .semibold : .medium, design: .default)
                                        .foregroundStyle(isActive ? taskTextColor : taskTextColor.opacity(0.65))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, isActive ? 12 : 10)
                                .frame(height: 34)
                                .background(isActive ? sheetBackgroundColor : sheetBackgroundColor.opacity(0.40), in: Capsule())
                                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                                .shadow(color: Color.black.opacity(isActive ? (isDark ? 0.04 : 0.02) : 0), radius: 3, x: 0, y: 1)
                            }
                            
                            // + Tab Button
                            Image(systemName: "plus")
                                .scaledFont(size: 11, weight: .bold)
                                .foregroundStyle(buttonIconColor)
                                .frame(width: 34, height: 34)
                                .background(sheetBackgroundColor, in: Circle())
                                .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                        }
                    } else {
                        // Title Capsule & Timer Pill for Tasks
                        HStack(spacing: 8) {
                            Text(note.title)
                                .scaledFont(size: 13, weight: .semibold, design: .default)
                                .foregroundStyle(taskTextColor)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(sheetBackgroundColor, in: Capsule())
                                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                                .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                            
                            // Pomodoro Timer Pill
                            HStack(spacing: 5) {
                                Image(systemName: note.isTimerRunning ? "pause.fill" : "play.fill")
                                    .scaledFont(size: 9.5, weight: .bold)
                                    .foregroundStyle(note.isTimerRunning ? Color.orange : buttonIconColor)
                                
                                Text(timeString)
                                    .scaledFont(size: 12.5, weight: .semibold, design: .rounded)
                                    .monospacedDigit()
                                    .foregroundStyle(note.isTimerRunning ? (isDark ? Color.white : Color.orange) : taskTextColor.opacity(0.88))
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(note.isTimerRunning ? timerHighlightGradient : specularBorderGradient, lineWidth: 0.75) }
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
                                    .scaledFont(size: 13, weight: .semibold)
                                    .foregroundStyle(buttonIconColor)
                                    .frame(width: 36, height: 36)
                                    .background(sheetBackgroundColor, in: Circle())
                                    .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            } else if isNotesType {
                                // Formatting Capsule (Bold, Italic, Bullets)
                                HStack(spacing: 12) {
                                    Image(systemName: "bold")
                                        .scaledFont(size: 12, weight: .bold)
                                        .foregroundStyle(buttonIconColor)
                                    Image(systemName: "italic")
                                        .scaledFont(size: 12, weight: .medium)
                                        .foregroundStyle(buttonIconColor)
                                    Image(systemName: "list.bullet")
                                        .scaledFont(size: 12, weight: .medium)
                                        .foregroundStyle(buttonIconColor)
                                }
                                .padding(.horizontal, 13)
                                .frame(height: 36)
                                .background(sheetBackgroundColor, in: Capsule())
                                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                                .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            } else {
                                // Add Button (+ Circle)
                                Image(systemName: "plus")
                                    .scaledFont(size: 13, weight: .semibold)
                                    .foregroundStyle(buttonIconColor)
                                    .frame(width: 36, height: 36)
                                    .background(sheetBackgroundColor, in: Circle())
                                    .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            }

                            Spacer()

                            // Right Action Capsule: Download, Pin, Cycle, Photo, Trash
                            HStack(spacing: 10) {
                                if isFinderType {
                                    Image(systemName: "key.fill")
                                        .scaledFont(size: 11.5, weight: .medium)
                                        .foregroundStyle(buttonIconColor)
                                } else {
                                    Image(systemName: "arrow.down.to.line")
                                        .scaledFont(size: 11.5, weight: .medium)
                                        .foregroundStyle(buttonIconColor)
                                }
                                Image(systemName: note.isPinned ? "pin.fill" : "pin")
                                    .scaledFont(size: 11.5, weight: .medium)
                                    .foregroundStyle(note.isPinned ? Color.orange : buttonIconColor)
                                Image(systemName: "arrow.clockwise")
                                    .scaledFont(size: 11.5, weight: .medium)
                                    .foregroundStyle(buttonIconColor)
                                Image(systemName: "photo.on.rectangle")
                                    .scaledFont(size: 11.5, weight: .medium)
                                    .foregroundStyle(buttonIconColor)
                                Image(systemName: "trash")
                                    .scaledFont(size: 11.5, weight: .medium)
                                    .foregroundStyle(buttonIconColor)
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 36)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
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
                                        .scaledFont(size: 12, weight: .medium)
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                
                                // File Match Cards
                                VStack(spacing: 5) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text.fill")
                                            .scaledFont(size: 13)
                                            .foregroundStyle(Color.red)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Tokens.swift")
                                                .scaledFont(size: 12, weight: .semibold)
                                                .foregroundStyle(taskTextColor)
                                            Text("2.4 KB · Modified Yesterday")
                                                .scaledFont(size: 10)
                                                .foregroundStyle(taskTextColor.opacity(0.50))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(sheetBackgroundColor.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(specularBorderGradient, lineWidth: 0.5) }

                                    HStack(spacing: 8) {
                                        Image(systemName: "app.badge.fill")
                                            .scaledFont(size: 13)
                                            .foregroundStyle(Color.orange)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("AppIcon.icns")
                                                .scaledFont(size: 12, weight: .semibold)
                                                .foregroundStyle(taskTextColor)
                                            Text("1.2 MB · Modified Today")
                                                .scaledFont(size: 10)
                                                .foregroundStyle(taskTextColor.opacity(0.50))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(sheetBackgroundColor.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(specularBorderGradient, lineWidth: 0.5) }
                                }

                                // AI Assistant Synthesis
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.red)
                                        .scaledFont(size: 11, weight: .bold)
                                        .padding(.top, 2)
                                    Text("Extracted liquid glass tokens and verified 1024×1024 Retina icon layers.")
                                        .scaledFont(size: 11.5, weight: .regular)
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
                        } else if isFoldersType {
                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "folder.fill")
                                                .scaledFont(size: 20)
                                                .foregroundStyle(.blue)
                                            Spacer()
                                            Text("3 notes")
                                                .scaledFont(size: 11, weight: .medium)
                                                .foregroundStyle(taskTextColor.opacity(0.5))
                                        }
                                        Spacer()
                                        Text("Projects")
                                            .scaledFont(size: 13.5, weight: .semibold)
                                            .foregroundStyle(taskTextColor)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, minHeight: 95)
                                    .background(sheetBackgroundColor.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(specularBorderGradient, lineWidth: 0.5) }

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "person.crop.circle.fill")
                                                .scaledFont(size: 20)
                                                .foregroundStyle(.blue)
                                            Spacer()
                                            Text("2 notes")
                                                .scaledFont(size: 11, weight: .medium)
                                                .foregroundStyle(taskTextColor.opacity(0.5))
                                        }
                                        Spacer()
                                        Text("Personal")
                                            .scaledFont(size: 13.5, weight: .semibold)
                                            .foregroundStyle(taskTextColor)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, minHeight: 95)
                                    .background(sheetBackgroundColor.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(specularBorderGradient, lineWidth: 0.5) }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .frame(maxHeight: .infinity)
                        } else if isNotesType {
                            let currentContent: String = note.pages.indices.contains(note.activePageIndex)
                                ? note.pages[note.activePageIndex].content
                                : note.noteContent
                            VStack(alignment: .leading, spacing: 0) {
                                if let attr = try? AttributedString(markdown: currentContent, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                    Text(attr)
                                        .scaledFont(size: 13.5, weight: .regular, design: .default)
                                        .lineSpacing(3.5)
                                        .foregroundStyle(taskTextColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                } else {
                                    Text(currentContent.isEmpty ? String(localized: "No notes recorded.") : currentContent)
                                        .scaledFont(size: 13.5, weight: .regular, design: .default)
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
                                            .scaledFont(size: 13.5, weight: .semibold, design: .rounded)
                                            .monospacedDigit()
                                            .foregroundStyle(
                                                item.isCompleted 
                                                    ? completedTaskColor.opacity(isDark ? 0.75 : 0.65)
                                                    : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40))
                                            )
                                            .frame(minWidth: 16, alignment: .leading)
                                            .padding(.top, 1)

                                        Text(item.text)
                                            .scaledFont(size: 13.5, weight: .regular, design: .default)
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
                                    .scaledFont(size: 12, weight: .medium)
                                    .foregroundStyle(taskTextColor.opacity(0.50))
                                Text("Ask notskyai or search files...")
                                    .scaledFont(size: 11.5)
                                    .foregroundStyle(taskTextColor.opacity(0.40))
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                    .scaledFont(size: 18)
                                    .foregroundStyle(Color.red)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .padding(.top, 4)
                        } else {
                            HStack {
                                if isNotesType {
                                    let plainText = (note.pages.indices.contains(note.activePageIndex) ? note.pages[note.activePageIndex].content : note.noteContent)
                                        .replacing("**", with: "").replacing("*", with: "")
                                    let words = plainText.split { $0.isWhitespace || $0.isNewline }.count
                                    let chars = plainText.count
                                    Text("\(words) words, \(chars) characters")
                                        .scaledFont(size: 11, weight: .medium, design: .rounded)
                                        .foregroundStyle(taskTextColor.opacity(0.50))
                                        .padding(.leading, 18)
                                }
                                Spacer()
                                Text("Add Group")
                                    .scaledFont(size: 12, weight: .medium, design: .default)
                                    .foregroundStyle(buttonIconColor)
                                    .padding(.horizontal, 13)
                                    .frame(height: 32)
                                    .background(sheetBackgroundColor, in: Capsule())
                                    .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
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
                            .scaledFont(size: 26, weight: .bold)
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
            "/Applications/Notsky Next.app/Contents/Resources/AppIcon.icns",
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
