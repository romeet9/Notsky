import SwiftUI
import AppKit

/// Markdown editor (with placeholder) for one page of a freeform note card.
struct FreeformEditorPane: View {
    let noteId: UUID
    let index: Int
    @Binding var text: String
    let noteFontSize: CGFloat
    let placeholderColor: Color
    let isDark: Bool
    let formatController: NoteTextFormatController
    let sheetHeight: CGFloat
    let contentWidth: CGFloat
    let cardWidth: CGFloat
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        let content = text
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("Write your quick notes here...")
                        .scaledFont(size: noteFontSize, weight: .regular, design: .default)
                        .foregroundStyle(placeholderColor)
                        .padding(.top, 4)
                        .padding(.leading, 2)
                        .allowsHitTesting(false)
                }

                MacMarkdownTextEditor(
                    text: $text,
                    fontSize: noteFontSize * CGFloat(settings.textScale),
                    textColor: isDark ? NSColor.white : NSColor.black,
                    placeholderText: String(localized: "Write your quick notes here..."),
                    placeholderColor: isDark ? NSColor.white.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.35),
                    formatController: formatController
                )
                .id("tab_editor_\(noteId)_\(index)")
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
}
