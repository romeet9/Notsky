import SwiftUI
import AppKit

/// Square document tile shown under an assistant reply in the Finder card.
struct FinderFileTile: View {
    let file: FinderFileItem
    let isDark: Bool
    let sheetBackgroundColor: Color
    let specularBorderGradient: LinearGradient

    var body: some View {
        Button(action: {
            SensoryFeedback.buttonClicked()
            let url = URL(fileURLWithPath: file.path)
            // Option-click reveals in Finder; apps and scripts are always revealed, never launched from here.
            if NSEvent.modifierFlags.contains(.option) || !FileSearch.isSafeToOpen(url) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Image(systemName: fileIconName(for: file.fileType))
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundStyle(fileBadgeColor(for: file.fileType))
                    
                    Spacer(minLength: 4)
                    
                    if !file.fileSize.isEmpty {
                        Text(file.fileSize)
                            .scaledFont(size: 10.5, weight: .medium, design: .rounded)
                            .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    }
                }
                
                Spacer(minLength: 8)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(file.name)
                        .scaledFont(size: 13, weight: .semibold, design: .default)
                        .tracking(-0.3)
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                    
                    if !file.formattedDate.isEmpty {
                        Text(file.formattedDate)
                            .scaledFont(size: 9.5, weight: .medium, design: .rounded)
                            .foregroundStyle(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.50))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 116)
            .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 5, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }
        }
        .help("Click to open \(file.name). Option-click to reveal in Finder.")
    }

    private func fileIconName(for ext: String) -> String {
        switch ext.lowercased() {
        case "folder": return "folder.fill"
        case "pdf": return "doc.text.fill"
        case "xlsx", "xls", "csv", "numbers": return "tablecells.fill"
        case "docx", "doc", "pages", "txt", "rtf": return "doc.fill"
        case "png", "jpg", "jpeg", "heic", "webp": return "photo.fill"
        case "swift", "py", "js", "ts", "json", "html", "css", "md": return "curlybraces"
        default: return "doc.fill"
        }
    }

    private func fileBadgeColor(for ext: String) -> Color {
        switch ext.lowercased() {
        case "folder": return Color(white: 0.70)
        case "pdf": return Color.red.opacity(0.85)
        case "xlsx", "xls", "csv", "numbers": return Color(white: 0.75)
        case "docx", "doc", "pages": return Color(white: 0.70)
        case "png", "jpg", "jpeg", "heic", "webp": return Color(white: 0.65)
        case "swift", "py", "js", "ts", "json", "html", "css", "md": return Color.red.opacity(0.75)
        default: return Color.gray.opacity(0.85)
        }
    }
}
