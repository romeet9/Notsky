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

// MARK: - Drawer Window Manager

@MainActor
public final class DrawerWindowManager: NSObject, ObservableObject {
    public static let shared = DrawerWindowManager()
    
    private var windowController: NSWindowController?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    @Published public private(set) var isVisible: Bool = false
    @Published public var isContentVisible: Bool = false
    
    private override init() {
        super.init()
    }
    
    public func toggleDrawer() {
        if isVisible {
            hideDrawer()
        } else {
            showDrawer()
        }
    }
    
    public func showDrawer() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return }
        
        let screenFrame = screen.frame
        
        if windowController == nil {
            let panel = DrawerPanel(
                contentRect: screenFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .none
            
            let shelfView = DrawerShelfView(onClose: { [weak self] in
                self?.hideDrawer()
            })
            
            let hostingView = NSHostingView(rootView: shelfView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
            panel.contentView = hostingView
            
            windowController = NSWindowController(window: panel)
        }
        
        guard let panel = windowController?.window else { return }
        
        panel.setFrame(screenFrame, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        
        isVisible = true
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.15)) {
            self.isContentVisible = true
        }
        
        startOutsideClickMonitors()
    }
    
    public func hideDrawer() {
        guard isVisible, let panel = windowController?.window else { return }
        
        stopOutsideClickMonitors()
        isVisible = false
        
        withAnimation(.spring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.10)) {
            self.isContentVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
            guard let self = self, !self.isVisible else { return }
            panel.orderOut(nil)
        }
    }
    
    // MARK: - Auto-Dismiss Event Monitors
    
    private func startOutsideClickMonitors() {
        stopOutsideClickMonitors()
        
        // Global monitor for clicks in other applications
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hideDrawer()
            }
        }
    }
    
    private func stopOutsideClickMonitors() {
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
    }
}
