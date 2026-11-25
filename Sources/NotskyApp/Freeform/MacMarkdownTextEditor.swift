import SwiftUI
import AppKit

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
        context.coordinator.lastRenderedFontSize = fontSize
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

        if context.coordinator.lastRenderedMarkdown != text || context.coordinator.lastRenderedFontSize != fontSize {
            context.coordinator.lastRenderedFontSize = fontSize
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
        var lastRenderedFontSize: CGFloat = 0

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
