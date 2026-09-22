import SwiftUI
import AppKit

@MainActor
public final class SettingsWindowManager: NSObject, ObservableObject, NSWindowDelegate, NSToolbarDelegate {
    public static let shared = SettingsWindowManager()
    
    @Published public var currentItem: SettingsSidebarItem = .general {
        didSet {
            window?.title = currentItem.rawValue
        }
    }
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showSettings(item: SettingsSidebarItem = .general) {
        self.currentItem = item
        
        if let existing = window {
            if existing.isMiniaturized { existing.deminiaturize(nil) }
            existing.title = currentItem.rawValue
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        let size = CGSize(width: 860, height: 580)
        
        // Stock macOS Split View Controller (as used in Tinycast / System Settings)
        let sidebarVC = NSHostingController(rootView: SettingsSidebarView())
        let detailVC = NSHostingController(rootView: SettingsDetailView())
        
        let splitVC = NSSplitViewController()
        
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 240
        sidebarItem.canCollapse = false
        
        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 500
        
        splitVC.addSplitViewItem(sidebarItem)
        splitVC.addSplitViewItem(detailItem)
        
        // Stock macOS Window setup
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        win.title = currentItem.rawValue
        win.titleVisibility = .visible
        win.toolbarStyle = .unified
        win.titlebarSeparatorStyle = .none
        win.titlebarAppearsTransparent = false
        win.isMovableByWindowBackground = false
        win.isReleasedWhenClosed = false
        win.contentMinSize = size
        win.delegate = self
        
        // Toolbar with sidebar tracking separator
        let toolbar = NSToolbar(identifier: "NotskySettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        win.toolbar = toolbar
        
        win.contentViewController = splitVC
        win.setContentSize(size)
        win.center()
        
        self.window = win
        
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - NSToolbarDelegate
    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }
    
    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }
    
    // MARK: - NSWindowDelegate
    public func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}
