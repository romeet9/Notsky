import AppKit

public final class MenuBarIconManager: @unchecked Sendable {
    public static let shared = MenuBarIconManager()
    
    public lazy var menuBarIcon: NSImage = {
        let targetSize = NSSize(width: 11, height: 14.5)
        
        let candidatePaths = [
            Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
            Bundle.main.path(forResource: "N", ofType: "svg"),
            "/Applications/Notsky.app/Contents/Resources/MenuBarIcon.png",
            "/Applications/Notsky.app/Contents/Resources/N.svg",
            "/Users/romeet/.gemini/antigravity/scratch/NotskyApp/Resources/MenuBarIcon.png",
            "/Users/romeet/Downloads/N.svg"
        ].compactMap { $0 }
        
        for path in candidatePaths {
            if let img = NSImage(contentsOfFile: path) {
                let templateImg = NSImage(size: targetSize)
                templateImg.lockFocus()
                img.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: img.size), operation: .sourceOver, fraction: 1.0)
                templateImg.unlockFocus()
                templateImg.isTemplate = true
                return templateImg
            }
        }
        
        let fallback = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notsky") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }()
    
    private init() {}
}
