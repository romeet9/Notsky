import SwiftUI
import AppKit

@main
struct NotskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Image(nsImage: MenuBarIconManager.shared.menuBarIcon)
        }
    }
}
