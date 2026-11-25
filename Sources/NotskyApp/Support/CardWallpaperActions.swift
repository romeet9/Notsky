import SwiftUI
import AppKit

/// Wallpaper cycling and custom header-image picking, shared by all four card views.
@MainActor
enum CardWallpaperActions {
    static func cycle(_ note: Binding<NoteCard>) {
        SensoryFeedback.buttonClicked()
        let nextPath = WallpaperPackManager.shared.cycleNextWallpaper(after: note.wrappedValue.headerImagePath)
        withMotion(.easeInOut(duration: 0.2)) {
            note.wrappedValue.headerImagePath = nextPath
        }
    }

    /// Shows an NSOpenPanel and applies the chosen image as the card header.
    static func chooseCustomImage(_ note: Binding<NoteCard>, panelTitle: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .heic, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = panelTitle
        guard panel.runModal() == .OK, let url = panel.url else { return }
        withMotion(.spring(response: 0.35, dampingFraction: 0.8)) {
            note.wrappedValue.headerImagePath = url.path
        }
        SensoryFeedback.buttonClicked()
    }
}
