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
        
        let nsAttr: NSMutableAttributedString
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            nsAttr = NSMutableAttributedString(attributed)
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
        } else {
            nsAttr = NSMutableAttributedString(string: markdown)
            let fullRange = NSRange(location: 0, length: nsAttr.length)
            nsAttr.addAttribute(.font, value: baseRegular, range: fullRange)
            nsAttr.addAttribute(.foregroundColor, value: textColor, range: fullRange)
        }
        
        // Apply Apple Notes style hanging indents & paragraph spacing
        let textStr = nsAttr.string as NSString
        var lineStart = 0
        while lineStart < textStr.length {
            let lineRange = textStr.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = textStr.substring(with: lineRange)
            let stripped = line.trimmingCharacters(in: .whitespaces)
            
            let pStyle = NSMutableParagraphStyle()
            pStyle.lineSpacing = 3.5
            pStyle.paragraphSpacing = 2.0
            
            let isBullet = stripped.hasPrefix("• ") || stripped.hasPrefix("◦ ") || stripped.hasPrefix("▪ ") || stripped.hasPrefix("☐ ") || stripped.hasPrefix("☑ ") || stripped.hasPrefix("› ") || stripped.hasPrefix("- ") || stripped.hasPrefix("* ")
            let isNumbered = stripped.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) != nil
            
            if isBullet || isNumbered {
                let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                let baseIndent = CGFloat(leadingSpaces * 8 + 18)
                pStyle.firstLineHeadIndent = CGFloat(leadingSpaces * 8)
                pStyle.headIndent = baseIndent
            }
            
            nsAttr.addAttribute(.paragraphStyle, value: pStyle, range: lineRange)
            lineStart = lineRange.location + lineRange.length
        }
        
        return nsAttr
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

// MARK: - Native Mac Rich Text View with Apple Notes Engine
final class NotskyRichTextView: NSTextView {
    
    // 1. Auto-Format on Space: - , * , + , 1. , [] , [x] , >
    override func insertText(_ string: Any, replacementRange: NSRange) {
        if let str = string as? String, str == " ", replacementRange.location == NSNotFound {
            let selectedRange = self.selectedRange()
            if selectedRange.length == 0 {
                let fullText = (self.string as NSString)
                if selectedRange.location <= fullText.length {
                    let lineRange = fullText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
                    let lineTextBeforeCursor = fullText.substring(with: NSRange(location: lineRange.location, length: selectedRange.location - lineRange.location))
                    
                    let indent = lineTextBeforeCursor.prefix(while: { $0 == " " || $0 == "\t" })
                    let stripped = String(lineTextBeforeCursor.dropFirst(indent.count))
                    
                    // Bullet list triggers: '-' or '*' or '+'
                    if stripped == "-" || stripped == "*" || stripped == "+" {
                        let replaceRange = NSRange(location: lineRange.location + indent.count, length: stripped.count)
                        super.insertText("• ", replacementRange: replaceRange)
                        SensoryFeedback.buttonClicked()
                        return
                    }
                    
                    // Checkbox triggers: '[]' or '[ ]'
                    if stripped == "[]" || stripped == "[ ]" {
                        let replaceRange = NSRange(location: lineRange.location + indent.count, length: stripped.count)
                        super.insertText("☐ ", replacementRange: replaceRange)
                        SensoryFeedback.buttonClicked()
                        return
                    }
                    
                    // Completed Checkbox: '[x]' or '[X]'
                    if stripped == "[x]" || stripped == "[X]" {
                        let replaceRange = NSRange(location: lineRange.location + indent.count, length: stripped.count)
                        super.insertText("☑ ", replacementRange: replaceRange)
                        SensoryFeedback.buttonClicked()
                        return
                    }
                    
                    // Blockquote / Arrow: '>'
                    if stripped == ">" {
                        let replaceRange = NSRange(location: lineRange.location + indent.count, length: stripped.count)
                        super.insertText("› ", replacementRange: replaceRange)
                        SensoryFeedback.buttonClicked()
                        return
                    }
                    
                    // Numbered list trigger: '1.' or '1)'
                    if stripped == "1." || stripped == "1)" {
                        let replaceRange = NSRange(location: lineRange.location + indent.count, length: stripped.count)
                        super.insertText("1. ", replacementRange: replaceRange)
                        SensoryFeedback.buttonClicked()
                        return
                    }
                }
            }
        }
        super.insertText(string, replacementRange: replacementRange)
    }
    
    // 2. Return / Enter: Auto-continue list or Smart Exit on empty line
    override func insertNewline(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        let string = (self.string as NSString)
        
        guard selectedRange.location <= string.length else {
            super.insertNewline(sender)
            return
        }
        
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let currentLine = string.substring(with: lineRange)
        
        let indent = currentLine.prefix(while: { $0 == " " || $0 == "\t" })
        let stripped = currentLine.dropFirst(indent.count)
        
        // Bullets ("• ", "◦ ", "▪ ", "- ", "* ", "+ ", "› ")
        let bulletSymbols = ["• ", "◦ ", "▪ ", "- ", "* ", "+ ", "› "]
        for symbol in bulletSymbols {
            if stripped.hasPrefix(symbol) {
                let contentAfter = stripped.dropFirst(symbol.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if contentAfter.isEmpty {
                    // Empty bullet: Exit list mode cleanly
                    let prefixRange = NSRange(location: lineRange.location, length: min(lineRange.length, indent.count + symbol.count))
                    if prefixRange.location + prefixRange.length <= string.length {
                        self.insertText("", replacementRange: prefixRange)
                        return
                    }
                } else {
                    // Continue with next bullet on new line
                    let nextBullet = "\n" + String(indent) + symbol
                    self.insertText(nextBullet, replacementRange: selectedRange)
                    return
                }
            }
        }
        
        // Checkboxes ("☐ ", "☑ ")
        let checkboxSymbols = ["☐ ", "☑ "]
        for symbol in checkboxSymbols {
            if stripped.hasPrefix(symbol) {
                let contentAfter = stripped.dropFirst(symbol.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if contentAfter.isEmpty {
                    // Exit checkbox mode
                    let prefixRange = NSRange(location: lineRange.location, length: min(lineRange.length, indent.count + symbol.count))
                    if prefixRange.location + prefixRange.length <= string.length {
                        self.insertText("", replacementRange: prefixRange)
                        return
                    }
                } else {
                    // Insert new unchecked box
                    let nextBox = "\n" + String(indent) + "☐ "
                    self.insertText(nextBox, replacementRange: selectedRange)
                    return
                }
            }
        }
        
        // Numbered lists ("1. ", "2. ")
        if let match = stripped.range(of: #"^(\d+)[\.\)]\s+"#, options: .regularExpression) {
            let numPrefix = String(stripped[match])
            let contentAfter = stripped.dropFirst(numPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if contentAfter.isEmpty {
                // Exit numbered list
                let prefixRange = NSRange(location: lineRange.location, length: min(lineRange.length, indent.count + numPrefix.count))
                if prefixRange.location + prefixRange.length <= string.length {
                    self.insertText("", replacementRange: prefixRange)
                    return
                }
            } else if let numDigits = numPrefix.components(separatedBy: CharacterSet(charactersIn: ".)")).first,
                      let currentNum = Int(numDigits.trimmingCharacters(in: .whitespaces)) {
                let separator = numPrefix.contains(")") ? ") " : ". "
                let nextNum = currentNum + 1
                let nextPrefix = "\n" + String(indent) + "\(nextNum)\(separator)"
                self.insertText(nextPrefix, replacementRange: selectedRange)
                return
            }
        }
        
        super.insertNewline(sender)
    }
    
    // 3. Smart Backspace: Outdent or Un-bullet
    override func deleteBackward(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        let string = (self.string as NSString)
        
        if selectedRange.length == 0 && selectedRange.location > 0 && selectedRange.location <= string.length {
            let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentLine = string.substring(with: lineRange)
            let indent = currentLine.prefix(while: { $0 == " " || $0 == "\t" })
            let stripped = currentLine.dropFirst(indent.count)
            
            // Check if cursor is right after list prefix
            let listPrefixes = ["• ", "◦ ", "▪ ", "- ", "* ", "+ ", "☐ ", "☑ ", "› "]
            for prefix in listPrefixes {
                if stripped.hasPrefix(prefix) {
                    let prefixEndLocation = lineRange.location + indent.count + prefix.count
                    if selectedRange.location == prefixEndLocation {
                        if indent.count >= 2 {
                            let indentRange = NSRange(location: lineRange.location, length: 2)
                            self.insertText("", replacementRange: indentRange)
                            return
                        } else {
                            let removeRange = NSRange(location: lineRange.location, length: indent.count + prefix.count)
                            self.insertText("", replacementRange: removeRange)
                            return
                        }
                    }
                }
            }
            
            // Check numbered list prefix
            if let match = stripped.range(of: #"^(\d+)[\.\)]\s+"#, options: .regularExpression) {
                let numPrefix = String(stripped[match])
                let prefixEndLocation = lineRange.location + indent.count + numPrefix.count
                if selectedRange.location == prefixEndLocation {
                    if indent.count >= 2 {
                        let indentRange = NSRange(location: lineRange.location, length: 2)
                        self.insertText("", replacementRange: indentRange)
                        return
                    } else {
                        let removeRange = NSRange(location: lineRange.location, length: indent.count + numPrefix.count)
                        self.insertText("", replacementRange: removeRange)
                        return
                    }
                }
            }
        }
        
        super.deleteBackward(sender)
    }
    
    // 4. Tab Key: Indent list level & cycle bullet style
    override func insertTab(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        let string = (self.string as NSString)
        
        if selectedRange.location <= string.length {
            let lineRange = string.lineRange(for: selectedRange)
            let currentLine = string.substring(with: lineRange)
            
            if currentLine.contains("• ") {
                let replaced = currentLine.replacingOccurrences(of: "• ", with: "  ◦ ")
                self.insertText(replaced, replacementRange: lineRange)
                return
            } else if currentLine.contains("◦ ") {
                let replaced = currentLine.replacingOccurrences(of: "◦ ", with: "  ▪ ")
                self.insertText(replaced, replacementRange: lineRange)
                return
            } else if currentLine.contains("▪ ") || currentLine.contains("☐ ") || currentLine.contains("☑ ") || currentLine.range(of: #"^\s*(\d+)[\.\)]\s+"#, options: .regularExpression) != nil {
                let replaced = "  " + currentLine
                self.insertText(replaced, replacementRange: lineRange)
                return
            }
        }
        
        self.insertText("  ", replacementRange: selectedRange)
    }
    
    // 5. Shift+Tab Key: Outdent list level
    override func insertBacktab(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        let string = (self.string as NSString)
        
        if selectedRange.location <= string.length {
            let lineRange = string.lineRange(for: selectedRange)
            let currentLine = string.substring(with: lineRange)
            
            if currentLine.hasPrefix("  ") {
                var newLine = String(currentLine.dropFirst(2))
                if newLine.hasPrefix("▪ ") {
                    newLine = "◦ " + String(newLine.dropFirst(2))
                } else if newLine.hasPrefix("◦ ") {
                    newLine = "• " + String(newLine.dropFirst(2))
                }
                self.insertText(newLine, replacementRange: lineRange)
                return
            }
        }
        
        super.insertBacktab(sender)
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
        let scrollView = NSScrollView(frame: .zero)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NotskyRichTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

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

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NotskyRichTextView else { return }
        
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
    @State private var isHoveringFolderMenu: Bool = false
    @State private var showFolderPopover: Bool = false
    @State private var showNewFolderDialog: Bool = false
    @State private var newFolderNameInput: String = ""
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
    
    // Width & Height driven by note model:
    // Default: 281 × 364 pt. Max: 586 × 752 pt.
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
    
    private let minCardWidth: Double = 281
    private let maxCardWidth: Double = 860
    private let minCardHeight: Double = 260
    private let maxCardHeight: Double = 752
    
    private var contentWidth: CGFloat { max(200, cardWidth - 46) }
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
            
            Menu("Move to Folder") {
                Button(action: {
                    note.folderId = nil
                    SensoryFeedback.buttonClicked()
                }) {
                    if note.folderId == nil {
                        Label("None (Uncategorized)", systemImage: "checkmark")
                    } else {
                        Text("None (Uncategorized)")
                    }
                }
                
                if !WidgetWindowManager.shared.store.folders.isEmpty {
                    Divider()
                    ForEach(WidgetWindowManager.shared.store.folders) { folder in
                        Button(action: {
                            note.folderId = folder.id
                            SensoryFeedback.buttonClicked()
                        }) {
                            if note.folderId == folder.id {
                                Label(folder.name, systemImage: "checkmark")
                            } else {
                                Label(folder.name, systemImage: folder.icon)
                            }
                        }
                    }
                }
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

    // MARK: - 2. Top Toolbar (Top-Left Formatting & Folder Menu + Top-Right Action Capsule)
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

    // MARK: - 4. Bottom Toolbar (Folder Label, Capsule Stats Label & Single Add Card Button)
    @ViewBuilder
    private func bottomToolbar(for index: Int) -> some View {
        let content = note.pages.indices.contains(index) ? note.pages[index].content : ""
        let words = wordCount(for: content)
        let chars = charCount(for: content)
        
        HStack(spacing: 8) {
            // Folder Selection Capsule on the bottom-left opposite Add Card (Solid white background label)
            Button(action: {
                SensoryFeedback.buttonClicked()
                showFolderPopover.toggle()
            }) {
                HStack(spacing: 6) {
                    let assignedFolder = WidgetWindowManager.shared.store.folder(for: note.folderId)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(assignedFolder?.name ?? "Folder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.65))
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.white, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringFolderMenu = $0 }
            .popover(isPresented: $showFolderPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                    
                    Button(action: {
                        note.folderId = nil
                        showFolderPopover = false
                        SensoryFeedback.buttonClicked()
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("None (Uncategorized)")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            if note.folderId == nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if !WidgetWindowManager.shared.store.folders.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                        
                        ForEach(WidgetWindowManager.shared.store.folders) { folder in
                            Button(action: {
                                note.folderId = folder.id
                                showFolderPopover = false
                                SensoryFeedback.buttonClicked()
                            }) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                    Text(folder.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if note.folderId == folder.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    Button(action: {
                        showFolderPopover = false
                        showNewFolderDialog = true
                        newFolderNameInput = ""
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 11.5))
                                .foregroundColor(.accentColor)
                            Text("New Folder...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .frame(width: 190)
            }
            .popover(isPresented: $showNewFolderDialog) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create New Folder")
                        .font(.system(size: 12, weight: .bold))
                    
                    TextField("Folder Name", text: $newFolderNameInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit {
                            let created = WidgetWindowManager.shared.store.createFolder(name: newFolderNameInput)
                            note.folderId = created.id
                            showNewFolderDialog = false
                            SensoryFeedback.taskAdded()
                        }
                    
                    HStack {
                        Button("Cancel") {
                            showNewFolderDialog = false
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Create") {
                            let created = WidgetWindowManager.shared.store.createFolder(name: newFolderNameInput)
                            note.folderId = created.id
                            showNewFolderDialog = false
                            SensoryFeedback.taskAdded()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(14)
            }
            .help("Assign to Folder")
            .padding(.leading, 16)

            // Word & Character count label inside 38pt Capsule — visible when width permits
            if cardWidth >= 380 || !showControls {
                HStack(spacing: 4) {
                    Text("\(words) \(words == 1 ? "word" : "words"), \(chars) \(chars == 1 ? "char" : "chars")")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(taskTextColor.opacity(0.88))
                }
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(sheetBackgroundColor, in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
            }

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
                        .frame(height: 38)
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


