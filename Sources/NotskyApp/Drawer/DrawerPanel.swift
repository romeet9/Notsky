import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Drawer NSPanel (Full Screen Transparent Overlay Canvas)

public final class DrawerPanel: NSPanel {
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public override func cancelOperation(_ sender: Any?) {
        // Dismiss on Esc key
        DrawerWindowManager.shared.hideDrawer()
    }
}
