import SwiftUI
import AppKit

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
            .replacing(" ", with: "-")
            .replacing("/", with: "-")
            .replacing(":", with: "-")
        let cleanName = safeTitle.isEmpty ? "Daily-Focus" : safeTitle
        
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        
        var targetURL = downloadsDirectory.appendingPathComponent("Notsky-\(cleanName).png")
        
        // If file exists, append timestamp so we never overwrite prior exports
        if FileManager.default.fileExists(atPath: targetURL.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date.now)
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
            Log.export.error("Failed to save 4K image: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// Opens the native macOS NSSavePanel for custom destination
    public static func saveCardImageAs(note: NoteCard, isDark: Bool) {
        guard let (nsImage, pngData) = render4KPNGData(note: note, isDark: isDark) else { return }
        
        let safeTitle = note.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(" ", with: "-")
        let cleanName = safeTitle.isEmpty ? "Daily-Focus" : safeTitle
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Notsky-\(cleanName).png"
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try pngData.write(to: url, options: .atomic)
            } catch {
                let alert = NSAlert()
                alert.messageText = String(localized: "Couldn't save image")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
            pasteboard.setData(pngData, forType: .png)
            
            SensoryFeedback.copied()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
