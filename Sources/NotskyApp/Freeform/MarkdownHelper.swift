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
