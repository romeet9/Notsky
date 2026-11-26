import SwiftUI
import AppKit

@main
struct NotskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        RemixIcon.registerFont()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Image(nsImage: MenuBarIconManager.shared.menuBarIcon)
        }
    }
}
