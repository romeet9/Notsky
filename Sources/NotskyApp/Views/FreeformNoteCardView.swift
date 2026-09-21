import SwiftUI
import AppKit

// MARK: - Markdown & Rich Text Attributes Helper
public enum MarkdownHelper {
    public static func markdownToAttributedString(
        _ markdown: String,
        baseFontSize: CGFloat,
        textColor: NSColor
    ) -> NSMutableAttributedString {
        let fontManager = NSFontManager.shared
        let baseRegular = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
        let baseBold = NSFont.systemFont(ofSize: baseFontSize, weight: .bold)
        let baseItalic = fontManager.convert(baseRegular, toHaveTrait: .italicFontMask)
        let baseBoldItalic = fontManager.convert(baseBold, toHaveTrait: .italicFontMask)
        
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let nsAttr = NSMutableAttributedString(attributed)
            let fullRange = NSRange(location: 0, length: nsAttr.length)
            
            nsAttr.enumerateAttribute(.font, in: fullRange, options: []) { value, subrange, _ in
                let currentFont = value as? NSFont
                let isBold = currentFont?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
                let isItalic = currentFont?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
                
                let font: NSFont
                if isBold && isItalic {
                    font = baseBoldItalic
                } else if isBold {
                    font = baseBold
                } else if isItalic {
                    font = baseItalic
                } else {
                    font = baseRegular
                }
                
                nsAttr.addAttribute(.font, value: font, range: subrange)
                nsAttr.addAttribute(.foregroundColor, value: textColor, range: subrange)
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3.5
            nsAttr.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            return nsAttr
        } else {
            let nsAttr = NSMutableAttributedString(string: markdown)
            let fullRange = NSRange(location: 0, length: nsAttr.length)
            nsAttr.addAttribute(.font, value: baseRegular, range: fullRange)
            nsAttr.addAttribute(.foregroundColor, value: textColor, range: fullRange)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3.5
            nsAttr.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            return nsAttr
        }
    }
    
    public static func attributedStringToMarkdown(_ attr: NSAttributedString) -> String {
        let str = attr.string as NSString
        if str.length == 0 { return "" }
        
        var result = ""
        let fullRange = NSRange(location: 0, length: attr.length)
        let fontManager = NSFontManager.shared
        
        attr.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            let chunk = str.substring(with: range)
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 15)
            let traits = fontManager.traits(of: font)
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)
            
            if isBold && isItalic {
                result += "***\(chunk)***"
            } else if isBold {
                result += "**\(chunk)**"
            } else if isItalic {
                result += "*\(chunk)*"
            } else {
                result += chunk
            }
        }
        return result
    }
}

// MARK: - Format Controller for Freeform Note Editor
public final class NoteTextFormatController: ObservableObject {
    public weak var textView: NSTextView?
    public var fontSize: CGFloat = 15.0
    public var textColor: NSColor = .white
    
    public init() {}
    
    public func toggleBold(in text: inout String) {
        guard let tv = textView, let textStorage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let fontManager = NSFontManager.shared
        
        if range.length == 0 {
            var typingAttrs = tv.typingAttributes
            let font = (typingAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: fontSize)
            let isBold = fontManager.traits(of: font).contains(.boldFontMask)
            let newFont = isBold
                ? fontManager.convert(font, toNotHaveTrait: .boldFontMask)
                : fontManager.convert(font, toHaveTrait: .boldFontMask)
            typingAttrs[.font] = newFont
            tv.typingAttributes = typingAttrs
            SensoryFeedback.buttonClicked()
            return
        }
        
        var allBold = true
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            if let font = value as? NSFont {
                if !fontManager.traits(of: font).contains(.boldFontMask) {
                    allBold = false
                }
            } else {
                allBold = false
            }
        }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? NSFont) ?? NSFont.systemFont(ofSize: fontSize)
            let newFont = allBold
                ? fontManager.convert(font, toNotHaveTrait: .boldFontMask)
                : fontManager.convert(font, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: newFont, range: subrange)
        }
        textStorage.endEditing()
        tv.didChangeText()
        text = MarkdownHelper.attributedStringToMarkdown(tv.attributedString())
        SensoryFeedback.buttonClicked()
    }
    
    public func toggleItalic(in text: inout String) {
        guard let tv = textView, let textStorage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let fontManager = NSFontManager.shared
        
        if range.length == 0 {
            var typingAttrs = tv.typingAttributes
            let font = (typingAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: fontSize)
            let isItalic = fontManager.traits(of: font).contains(.italicFontMask)
            let newFont = isItalic
                ? fontManager.convert(font, toNotHaveTrait: .italicFontMask)
                : fontManager.convert(font, toHaveTrait: .italicFontMask)
            typingAttrs[.font] = newFont
            tv.typingAttributes = typingAttrs
            SensoryFeedback.buttonClicked()
            return
        }
        
        var allItalic = true
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            if let font = value as? NSFont {
                if !fontManager.traits(of: font).contains(.italicFontMask) {
                    allItalic = false
                }
            } else {
                allItalic = false
            }
        }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? NSFont) ?? NSFont.systemFont(ofSize: fontSize)
            let newFont = allItalic
                ? fontManager.convert(font, toNotHaveTrait: .italicFontMask)
                : fontManager.convert(font, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: newFont, range: subrange)
        }
        textStorage.endEditing()
        tv.didChangeText()
        text = MarkdownHelper.attributedStringToMarkdown(tv.attributedString())
        SensoryFeedback.buttonClicked()
    }
    
    public func toggleBullets(in text: inout String) {
        guard let tv = textView, let textStorage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let string = textStorage.string as NSString
        let lineRange = string.lineRange(for: range)
        let paragraph = string.substring(with: lineRange)
        
        let lines = paragraph.components(separatedBy: "\n")
        var newLines: [String] = []
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 && line.isEmpty && lines.count > 1 {
                newLines.append("")
                continue
            }
            if line.hasPrefix("• ") {
                newLines.append(String(line.dropFirst(2)))
            } else if line.hasPrefix("- ") {
                newLines.append(String(line.dropFirst(2)))
            } else {
                newLines.append("• " + line)
            }
        }
        let replacement = newLines.joined(separator: "\n")
        tv.insertText(replacement, replacementRange: lineRange)
        text = MarkdownHelper.attributedStringToMarkdown(tv.attributedString())
        SensoryFeedback.buttonClicked()
    }
}

// MARK: - Native Mac Rich Text Editor Representable
struct MacMarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var textColor: NSColor
    var placeholderText: String
    var placeholderColor: NSColor
    var formatController: NoteTextFormatController

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.insertionPointColor = textColor

        let attr = MarkdownHelper.markdownToAttributedString(text, baseFontSize: fontSize, textColor: textColor)
        textView.textStorage?.setAttributedString(attr)

        context.coordinator.textView = textView
        context.coordinator.lastRenderedMarkdown = text
        formatController.textView = textView
        formatController.fontSize = fontSize
        formatController.textColor = textColor

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        context.coordinator.parent = self
        formatController.textView = textView
        formatController.fontSize = fontSize
        formatController.textColor = textColor
        textView.insertionPointColor = textColor

        if context.coordinator.lastRenderedMarkdown != text {
            let selectedRange = textView.selectedRange()
            let attr = MarkdownHelper.markdownToAttributedString(text, baseFontSize: fontSize, textColor: textColor)
            textView.textStorage?.setAttributedString(attr)
            context.coordinator.lastRenderedMarkdown = text
            if selectedRange.location + selectedRange.length <= (attr.string as NSString).length {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMarkdownTextEditor
        weak var textView: NSTextView?
        var lastRenderedMarkdown: String = ""

        init(_ parent: MacMarkdownTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let markdown = MarkdownHelper.attributedStringToMarkdown(textView.attributedString())
            self.lastRenderedMarkdown = markdown
            self.parent.text = markdown
        }
    }
}


@MainActor
public struct FreeformNoteCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = AppSettings.shared
    @Binding public var note: NoteCard
    public var onSpawnWidget: () -> Void
    public var onDelete: () -> Void
    
    @StateObject private var formatController = NoteTextFormatController()
    
    @State private var isEditingTabIndex: Int? = nil
    @FocusState private var isTabFocused: Bool
    @State private var hoveredTabIndex: Int? = nil
    @State private var isHoveringPlusTab: Bool = false
    @State private var isHoveringCard: Bool = false
    @State private var isHoveringBold: Bool = false
    @State private var isHoveringItalic: Bool = false
    @State private var isHoveringBullet: Bool = false
    @State private var isHoveringDownload: Bool = false
    @State private var isDownloaded: Bool = false
    @State private var isHoveringPin: Bool = false
    @State private var isHoveringCycle: Bool = false
    @State private var isHoveringGallery: Bool = false
    @State private var isHoveringTrash: Bool = false
    @State private var isHoveringNewCard: Bool = false
    @State private var isHoveringResizeW: Bool = false
    @State private var isHoveringResizeH: Bool = false
    @State private var isHoveringResizeCorner: Bool = false
    
    // Drag initial dimensions for smooth resizing
    @State private var dragInitialWidth: Double? = nil
    @State private var dragInitialHeight: Double? = nil
    
    // Directional slide animation state for tabs
    @State private var slideDirection: Edge = .trailing
    
    private var showControls: Bool {
        !settings.autoHideControls || isHoveringCard
    }
    
    // Width defaults to sum of 2 cards + 24pt spacing: 281 * 2 + 24 = 586 pt
    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    
    // Spacing between tab cards when sliding
    private let tabGap: CGFloat = 24.0
    
    // Weighted jelly bouncy spring animation for macOS fluid interaction
    private var tabSlideAnimation: Animation {
        .spring(response: 0.44, dampingFraction: 0.64, blendDuration: 0.16)
    }
    
    private let minCardWidth: Double = 360
    private let maxCardWidth: Double = 860
    private let minCardHeight: Double = 260
    private let maxCardHeight: Double = 800
    
    private var contentWidth: CGFloat { max(240, cardWidth - 46) }
    private var toolbarWidth: CGFloat { max(220, cardWidth - 28) }
    
    // MARK: - Adaptive Styling & Optical Depth
    private var isDark: Bool {
        if let override = settings.preferredColorScheme {
            return override == .dark
        }
        return colorScheme == .dark
    }
    
    private var sheetBackgroundColor: Color {
        let opacity = settings.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }
    
    private var noteFontSize: CGFloat {
        switch settings.interfaceScale {
        case "Small": return 13.5
        case "Large": return 16.5
        default: return 15.0
        }
    }
    
    private var noteTextColor: Color {
        isDark ? Color.white : Color.black
    }
    
    private var placeholderColor: Color {
        isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
    }
    
    private var buttonIconColor: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.75)
    }
    
    private func buttonBackgroundColor(hovering: Bool) -> Color {
        if isDark {
            return hovering ? Color(white: 0.16).opacity(0.90) : sheetBackgroundColor
        } else {
            return hovering ? Color.white.opacity(0.98) : sheetBackgroundColor
        }
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
    
    private var currentPages: [NotePage] {
        if note.pages.isEmpty {
            return [NotePage(title: note.title.isEmpty ? "Quick Note" : note.title, content: note.noteContent)]
        }
        return note.pages
    }
    
    private func contentBinding(for index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                if note.pages.indices.contains(index) {
                    return note.pages[index].content
                }
                return note.noteContent
            },
            set: { newValue in
                ensurePagesInitialized()
                if note.pages.indices.contains(index) {
                    note.pages[index].content = newValue
                    if index == note.activePageIndex {
                        note.noteContent = newValue
                    }
                }
            }
        )
    }
    
    private func wordCount(for text: String) -> Int {
        let plain = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
        let words = plain.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }
    
    private func charCount(for text: String) -> Int {
        let plain = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
        return plain.count
    }

    public init(
        note: Binding<NoteCard>,
        onSpawnWidget: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self._note = note
        self.onSpawnWidget = onSpawnWidget
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // 1. Full-Card Background Image
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // 2. Foreground Content Sheet — Multi-Tab Sliding Track with Distinct Gap & Bouncy Spring
            HStack(spacing: tabGap) {
                ForEach(Array(currentPages.enumerated()), id: \.element.id) { index, page in
                    ZStack(alignment: .top) {
                        // Frosted Glass Tint & Hardware Accelerated Material
                        sheetBackgroundColor
                            .background(.ultraThinMaterial)

                        // Main Notes Content for this tab page
                        VStack(spacing: 0) {
                            topToolbar
                            notesEditorArea(for: index)
                            bottomToolbar(for: index)
                        }
                    }
                    .frame(width: cardWidth, height: sheetHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                }
            }
            .offset(x: -CGFloat(min(note.activePageIndex, max(0, currentPages.count - 1))) * (cardWidth + tabGap))
            .animation(tabSlideAnimation, value: note.activePageIndex)
            .frame(width: cardWidth, height: sheetHeight, alignment: .leading)
            .offset(y: headerHeight)
            .zIndex(1)

            // 3. Top Title Tab Bar (Tabs + Plus Button) — Centered horizontally
            headerTitleCapsule
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)

            // 4. Resize Drag Handles — Elevated above all content to ensure instant edge grabbing
            resizeHandles
                .zIndex(100)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.20), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.08 : 0.04), radius: 6, x: 0, y: 2)
        .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            ensurePagesInitialized()
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                isHoveringCard = hovering
            }
        }
        .contextMenu {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isDownloaded = true
                }
                CardImageExporter.downloadCardImage(note: note, isDark: isDark)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDownloaded = false
                    }
                }
            }) {
                Label("Download 4K Card Image (Downloads)", systemImage: "arrow.down.to.line")
            }
            
            Button(action: {
                CardImageExporter.saveCardImageAs(note: note, isDark: isDark)
            }) {
                Label("Save 4K Card Image As...", systemImage: "square.and.arrow.down")
            }
            
            Divider()
            
            Button(action: {
                selectCustomHeaderImage()
            }) {
                Label("Change Header Image...", systemImage: "photo.on.rectangle")
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    note.isPinned.toggle()
                    WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                }
            }) {
                Label(note.isPinned ? "Unpin (Wallpaper Canvas Mode)" : "Pin on Top (Floating)", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                SensoryFeedback.taskDeleted()
                onDelete()
            }) {
                Label("Delete Note Widget", systemImage: "trash")
            }
        }
    }

    // MARK: - 1. Top Header Tab Bar (Title Tabs + Plus Button) — Centered
    @ViewBuilder
    private var headerTitleCapsule: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(Array(currentPages.enumerated()), id: \.offset) { index, page in
                    let isActive = (note.activePageIndex == index)
                    let isEditingThisTab = (isEditingTabIndex == index)
                    
                    if isEditingThisTab {
                        HStack(spacing: 4) {
                            TextField("Title", text: Binding(
                                get: { index < note.pages.count ? note.pages[index].title : page.title },
                                set: { val in
                                    ensurePagesInitialized()
                                    if index < note.pages.count { note.pages[index].title = val }
                                }
                            ))
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(taskTextColor)
                            .focused($isTabFocused)
                            .onSubmit {
                                SensoryFeedback.buttonClicked()
                                isEditingTabIndex = nil
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(sheetBackgroundColor, in: Capsule())
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                        .shadow(color: Color.black.opacity(isDark ? 0.04 : 0.02), radius: 3, x: 0, y: 1)
                    } else {
                        Button(action: {
                            ensurePagesInitialized()
                            if isActive {
                                isEditingTabIndex = index
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isTabFocused = true
                                }
                            } else {
                                isEditingTabIndex = nil
                                let newDirection: Edge = (index > note.activePageIndex) ? .trailing : .leading
                                self.slideDirection = newDirection
                                withAnimation(tabSlideAnimation) {
                                    note.activePageIndex = index
                                }
                            }
                            SensoryFeedback.buttonClicked()
                        }) {
                            HStack(spacing: 6) {
                                Text(page.title.isEmpty ? "Note \(index + 1)" : page.title)
                                    .font(.system(size: 13, weight: isActive ? .semibold : .medium, design: .default))
                                    .foregroundStyle(isActive ? taskTextColor : taskTextColor.opacity(0.65))
                                    .lineLimit(1)

                                if note.pages.count > 1 {
                                    Button(action: {
                                        deleteTab(at: index)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(isActive ? taskTextColor.opacity(0.85) : taskTextColor.opacity(0.50))
                                            .frame(width: 14, height: 14)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete Note Tab")
                                }
                            }
                            .padding(.horizontal, isActive ? 14 : 12)
                            .frame(height: 36)
                            .background(
                                isActive ? sheetBackgroundColor : sheetBackgroundColor.opacity(0.40),
                                in: Capsule()
                            )
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(isActive ? specularBorderGradient : LinearGradient(colors: [Color.white.opacity(isDark ? 0.12 : 0.35), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: isActive ? 0.75 : 0.5)
                            )
                            .shadow(color: Color.black.opacity(isActive ? (isDark ? 0.04 : 0.02) : 0), radius: 3, x: 0, y: 1)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in
                            hoveredTabIndex = inside ? index : nil
                        }
                        .contextMenu {
                            Button("Rename Tab") {
                                ensurePagesInitialized()
                                isEditingTabIndex = index
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isTabFocused = true
                                }
                            }
                            if note.pages.count > 1 {
                                Button(role: .destructive, action: {
                                    deleteTab(at: index)
                                }) {
                                    Label("Delete Tab", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Plus (+) Button to Add a New Tab (Max 3 Tabs)
                if canAddTab {
                    Button(action: {
                        addNewTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(buttonIconColor)
                            .frame(width: 36, height: 36)
                            .background(buttonBackgroundColor(hovering: isHoveringPlusTab), in: Circle())
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                            )
                            .shadow(color: Color.black.opacity(isDark ? 0.04 : 0.02), radius: 3, x: 0, y: 1)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPlusTab = $0 }
                    .help("Add New Note Tab")
                }
            }
            .frame(maxWidth: cardWidth - 28, alignment: .center)

            Spacer(minLength: 0)
        }
    }

    private var taskTextColor: Color {
        isDark ? Color.white : Color.black
    }

    // MARK: - 2. Top Toolbar (Top-Left Formatting + Top-Right Action Capsule)
    @ViewBuilder
    private var topToolbar: some View {
        HStack {
            // Top-Left Formatting Capsule (Bold, Italic, Pointers) — ALWAYS VISIBLE
            HStack(spacing: 12) {
                // Bold Button
                Button(action: {
                    formatActiveContentBold()
                }) {
                    Image(systemName: "bold")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringBold = $0 }
                .help("Bold Text (**bold**)")

                // Italic Button
                Button(action: {
                    formatActiveContentItalic()
                }) {
                    Image(systemName: "italic")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringItalic = $0 }
                .help("Italic Text (*italic*)")

                // Bullet Points Button
                Button(action: {
                    formatActiveContentBullets()
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringBullet = $0 }
                .help("Add Bullet Points (•)")
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(buttonBackgroundColor(hovering: isHoveringBold || isHoveringItalic || isHoveringBullet), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)

            Spacer()

            // Top-Right Action Buttons Capsule — AUTO-HIDDEN (Slides in from Trailing Edge on Hover)
            if showControls {
                HStack(spacing: 12) {
                    // Download 4K Card Image Button
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            isDownloaded = true
                        }
                        CardImageExporter.downloadCardImage(note: note, isDark: isDark)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDownloaded = false
                            }
                        }
                    }) {
                        Image(systemName: isDownloaded ? "checkmark" : "arrow.down.to.line")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isDownloaded ? Color.green : buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringDownload = $0 }
                    .help(isDownloaded ? "Saved 4K Image to Downloads!" : "Download 4K Image (for LinkedIn, Instagram, Twitter)")

                    // Pin on Top / Wallpaper Canvas Toggle
                    Button(action: {
                        SensoryFeedback.buttonClicked()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            note.isPinned.toggle()
                            WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                        }
                    }) {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(note.isPinned ? Color.orange : buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPin = $0 }
                    .help(note.isPinned ? "Pinned on Top (Click to stick to Wallpaper)" : "Pin on Top (Float above all windows)")

                    // Cycle Next Wallpaper in Pack
                    Button(action: {
                        cycleWallpaper()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringCycle = $0 }
                    .help("Next Wallpaper in Pack")

                    // Change Header Image / Wallpaper Button
                    Button(action: {
                        SensoryFeedback.buttonClicked()
                        selectCustomHeaderImage()
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringGallery = $0 }
                    .help("Change Header Image")

                    // Delete Button
                    Button(action: {
                        SensoryFeedback.taskDeleted()
                        onDelete()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringTrash = $0 }
                    .help("Delete Note Widget")
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(buttonBackgroundColor(hovering: isHoveringDownload || isHoveringPin || isHoveringCycle || isHoveringGallery || isHoveringTrash), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showControls)
        .frame(width: toolbarWidth)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - 3. Notes Editor Area (Bound to Tab Index)
    @ViewBuilder
    private func notesEditorArea(for index: Int) -> some View {
        let content = note.pages.indices.contains(index) ? note.pages[index].content : ""
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("Write your quick notes here...")
                        .font(.system(size: noteFontSize, weight: .regular, design: .default))
                        .foregroundStyle(placeholderColor)
                        .padding(.top, 4)
                        .padding(.leading, 2)
                        .allowsHitTesting(false)
                }

                MacMarkdownTextEditor(
                    text: contentBinding(for: index),
                    fontSize: noteFontSize,
                    textColor: isDark ? NSColor.white : NSColor.black,
                    placeholderText: "Write your quick notes here...",
                    placeholderColor: isDark ? NSColor.white.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.35),
                    formatController: formatController
                )
                .id("tab_editor_\(note.id)_\(index)")
                .frame(minHeight: max(60, sheetHeight - 126))
            }
            .frame(width: contentWidth, alignment: .topLeading)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .frame(width: cardWidth)
        .frame(maxHeight: .infinity)
        .contentEdgeFade(top: 10, bottom: 14)
    }

    private var canAddTab: Bool {
        note.pages.count < 3
    }

    // MARK: - 4. Bottom Toolbar (Capsule Stats Label & Single Add Card Button)
    @ViewBuilder
    private func bottomToolbar(for index: Int) -> some View {
        let content = note.pages.indices.contains(index) ? note.pages[index].content : ""
        let words = wordCount(for: content)
        let chars = charCount(for: content)
        
        HStack {
            // Word & Character count label inside 40pt Capsule — ALWAYS VISIBLE
            HStack(spacing: 4) {
                Text("\(words) \(words == 1 ? "word" : "words"), \(chars) \(chars == 1 ? "character" : "characters")")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(taskTextColor.opacity(0.88))
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(sheetBackgroundColor, in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
            .padding(.leading, 16)

            Spacer()

            // Single Direct "Add Card" Button — AUTO-HIDDEN (Slides in from Trailing Edge on Hover)
            if showControls {
                Button(action: {
                    SensoryFeedback.widgetSpawned()
                    if let origin = WidgetWindowManager.shared.windowOrigin(for: note.id) {
                        WidgetWindowManager.shared.spawnNewFreeformNoteWidget(near: origin)
                    } else {
                        WidgetWindowManager.shared.spawnNewFreeformNoteWidget()
                    }
                }) {
                    Text("Add Card")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(buttonIconColor)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(buttonBackgroundColor(hovering: isHoveringNewCard), in: Capsule())
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringNewCard = $0 }
                .help("Add New Freeform Note Card")
                .padding(.trailing, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showControls)
        .frame(width: cardWidth)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }

    // MARK: - Multi-Tab Actions
    private func ensurePagesInitialized() {
        if note.pages.isEmpty {
            note.pages = [NotePage(title: "Note 1", content: note.noteContent)]
            note.activePageIndex = 0
        }
    }
    
    private func addNewTab() {
        ensurePagesInitialized()
        guard note.pages.count < 3 else { return }
        let nextIndex = note.pages.count + 1
        let title = "Note \(nextIndex)"
        let newPage = NotePage(title: title, content: "")
        self.slideDirection = .trailing
        withAnimation(tabSlideAnimation) {
            note.pages.append(newPage)
            note.activePageIndex = note.pages.count - 1
            isEditingTabIndex = nil
        }
        SensoryFeedback.buttonClicked()
    }
    
    private func deleteTab(at index: Int) {
        ensurePagesInitialized()
        guard note.pages.count > 1, note.pages.indices.contains(index) else { return }
        self.slideDirection = .leading
        withAnimation(tabSlideAnimation) {
            note.pages.remove(at: index)
            if note.activePageIndex >= note.pages.count {
                note.activePageIndex = max(0, note.pages.count - 1)
            }
        }
        SensoryFeedback.taskDeleted()
    }
    
    private func formatActiveContentBold() {
        if note.pages.indices.contains(note.activePageIndex) {
            formatController.toggleBold(in: &note.pages[note.activePageIndex].content)
        } else {
            formatController.toggleBold(in: &note.noteContent)
        }
    }
    
    private func formatActiveContentItalic() {
        if note.pages.indices.contains(note.activePageIndex) {
            formatController.toggleItalic(in: &note.pages[note.activePageIndex].content)
        } else {
            formatController.toggleItalic(in: &note.noteContent)
        }
    }
    
    private func formatActiveContentBullets() {
        if note.pages.indices.contains(note.activePageIndex) {
            formatController.toggleBullets(in: &note.pages[note.activePageIndex].content)
        } else {
            formatController.toggleBullets(in: &note.noteContent)
        }
    }


    // MARK: - Helpers
    private func cycleWallpaper() {
        SensoryFeedback.buttonClicked()
        let nextPath = WallpaperPackManager.shared.cycleNextWallpaper(after: note.headerImagePath)
        withAnimation(.easeInOut(duration: 0.2)) {
            note.headerImagePath = nextPath
        }
    }

    private func selectCustomHeaderImage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image, .heic, .png, .jpeg]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Select Note Card Background Image"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                note.headerImagePath = url.path
            }
            SensoryFeedback.buttonClicked()
        }
    }

    // MARK: - 5. Resize Drag Handles
    @ViewBuilder
    private var resizeHandles: some View {
        // Right Edge
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: 20, height: max(20, cardHeight - 20))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialWidth == nil { dragInitialWidth = note.width }
                            let base = dragInitialWidth ?? note.width
                            let newW = max(minCardWidth, min(maxCardWidth, base + Double(value.translation.width)))
                            if abs(note.width - newW) >= 0.5 {
                                note.width = newW
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: note.height)
                            }
                        }
                        .onEnded { _ in
                            dragInitialWidth = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeW = inside
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topTrailing)

        // Bottom Edge
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: max(20, cardWidth - 20), height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialHeight == nil { dragInitialHeight = note.height }
                            let base = dragInitialHeight ?? note.height
                            let newH = max(minCardHeight, min(maxCardHeight, base + Double(value.translation.height)))
                            if abs(note.height - newH) >= 0.5 {
                                note.height = newH
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: note.width, newHeight: newH)
                            }
                        }
                        .onEnded { _ in
                            dragInitialHeight = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeH = inside
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomLeading)

        // Bottom-Right Corner
        VStack {
            Spacer()
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if dragInitialWidth == nil { dragInitialWidth = note.width }
                                if dragInitialHeight == nil { dragInitialHeight = note.height }
                                let baseW = dragInitialWidth ?? note.width
                                let baseH = dragInitialHeight ?? note.height
                                let newW = max(minCardWidth, min(maxCardWidth, baseW + Double(value.translation.width)))
                                let newH = max(minCardHeight, min(maxCardHeight, baseH + Double(value.translation.height)))
                                if abs(note.width - newW) >= 0.5 || abs(note.height - newH) >= 0.5 {
                                    note.width = newW
                                    note.height = newH
                                    WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: newH)
                                }
                            }
                            .onEnded { _ in
                                dragInitialWidth = nil
                                dragInitialHeight = nil
                                SensoryFeedback.buttonClicked()
                            }
                    )
                    .onHover { inside in
                        isHoveringResizeCorner = inside
                        if inside {
                            NSCursor.crosshair.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomTrailing)
    }
}


