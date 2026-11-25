import SwiftUI
import AppKit

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
                let replaced = currentLine.replacing("• ", with: "  ◦ ")
                self.insertText(replaced, replacementRange: lineRange)
                return
            } else if currentLine.contains("◦ ") {
                let replaced = currentLine.replacing("◦ ", with: "  ▪ ")
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
