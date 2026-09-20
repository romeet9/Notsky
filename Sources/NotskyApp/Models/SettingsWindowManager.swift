import SwiftUI
import AppKit

@MainActor
public final class SettingsWindowManager: ObservableObject {
    public static let shared = SettingsWindowManager()
    
    private var windowController: NSWindowController?
    @Published public var currentItem: SettingsSidebarItem = .general
    
    private init() {}
    
    public func showSettings(item: SettingsSidebarItem = .general) {
        self.currentItem = item
        
        if let controller = windowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Raycast-style Native macOS Settings Window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Notsky Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.11, green: 0.09, blue: 0.10, alpha: 1.0)
        window.center()
        
        let hostingView = NSHostingView(
            rootView: SettingsHostView(manager: self)
        )
        window.contentView = hostingView
        
        let controller = NSWindowController(window: window)
        self.windowController = controller
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct SettingsHostView: View {
    @ObservedObject var manager: SettingsWindowManager
    
    var body: some View {
        SettingsView(selectedItem: $manager.currentItem)
    }
}
