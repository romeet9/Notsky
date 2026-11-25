import SwiftUI
import AppKit

// MARK: - Format Controller for Freeform Note Editor
@Observable
public final class NoteTextFormatController {
    @ObservationIgnored public weak var textView: NSTextView?
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
