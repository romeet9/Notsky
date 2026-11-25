import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Native Drag & Auto-Snap Widget Panel

public final class WidgetPanel: NSPanel {
    public var noteId: UUID? = nil
    
    private var isDraggingThisPanel: Bool = false
    private var didDragMoved: Bool = false
    private var dragStartMouseLocation: CGPoint = .zero
    private var dragOffsetFromWindowOrigin: CGPoint = .zero
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let mouseInWin = event.locationInWindow
            // Header area across top 110pt of card, excluding window resize borders
            let isRightEdge = mouseInWin.x >= (self.frame.width - 24)
            let isBottomEdge = mouseInWin.y <= 24
            let isLeftEdge = mouseInWin.x <= 24
            let isHeaderY = (mouseInWin.y >= (self.frame.height - 110)) && (mouseInWin.y <= (self.frame.height - 15))
            let isHeaderX = (mouseInWin.x >= 30) && (mouseInWin.x <= (self.frame.width - 30))
            let isHeader = isHeaderY && isHeaderX && !isRightEdge && !isBottomEdge && !isLeftEdge
            
            if isHeader {
                let screenMouse = NSEvent.mouseLocation
                self.dragStartMouseLocation = screenMouse
                self.dragOffsetFromWindowOrigin = CGPoint(
                    x: screenMouse.x - self.frame.origin.x,
                    y: screenMouse.y - self.frame.origin.y
                )
                self.isDraggingThisPanel = true
                if let noteId = self.noteId {
                    WidgetWindowManager.shared.beginDragging(noteId: noteId)
                }
            } else {
                self.isDraggingThisPanel = false
            }
            self.didDragMoved = false
            super.sendEvent(event)
            
        case .leftMouseDragged:
            if self.isDraggingThisPanel {
                let screenMouse = NSEvent.mouseLocation
                let dx = abs(screenMouse.x - dragStartMouseLocation.x)
                let dy = abs(screenMouse.y - dragStartMouseLocation.y)
                
                if dx > 4 || dy > 4 {
                    self.didDragMoved = true
                    let newX = screenMouse.x - dragOffsetFromWindowOrigin.x
                    let newY = screenMouse.y - dragOffsetFromWindowOrigin.y
                    
                    self.setFrameOrigin(CGPoint(x: newX, y: newY))
                    
                    if let noteId = self.noteId {
                        WidgetWindowManager.shared.updateDrag(noteId: noteId, screenMouse: screenMouse, panel: self)
                    }
                    return
                }
            }
            super.sendEvent(event)
            
        case .leftMouseUp:
            if self.isDraggingThisPanel {
                self.isDraggingThisPanel = false
                let wasMoved = self.didDragMoved
                if let noteId = self.noteId {
                    WidgetWindowManager.shared.endDrag(noteId: noteId, panel: self, didMove: wasMoved)
                }
                self.didDragMoved = false
                if wasMoved {
                    return
                }
            }
            super.sendEvent(event)
            
        default:
            super.sendEvent(event)
        }
    }
}
