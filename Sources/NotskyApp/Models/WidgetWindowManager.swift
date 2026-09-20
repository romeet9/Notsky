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
                if let noteId = self.noteId {
                    WidgetWindowManager.shared.endDrag(noteId: noteId, panel: self, didMove: self.didDragMoved)
                }
                self.didDragMoved = false
                return
            }
            super.sendEvent(event)
            
        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - Manager

@MainActor
public final class WidgetWindowManager: NSObject, ObservableObject {
    public static let shared = WidgetWindowManager()
    
    private var windowControllers: [UUID: NSWindowController] = [:]
    public var store = NoteStore()
    
    private var lastPreviewTargetCol: Int? = nil
    private var lastPreviewTargetRow: Int? = nil
    private var dragStartSlots: [UUID: (col: Int, row: Int)] = [:]
    private var activePreviewSlots: [UUID: (col: Int, row: Int)] = [:]
    
    private override init() {
        super.init()
    }
    
    public func start() {
        if store.notes.isEmpty {
            store.addNote()
        }
        
        for (index, note) in store.notes.enumerated() {
            let cardH = CGFloat(note.height)
            let origin = GridSnapManager.shared.cardOrigin(forCol: note.gridCol, row: note.gridRow, cardHeight: cardH)
            store.notes[index].positionX = origin.x
            store.notes[index].positionY = origin.y
            openWidgetWindow(for: note.id, at: origin)
        }
    }
    
    public func openWidgetWindow(for noteId: UUID, at origin: CGPoint? = nil) {
        if let existing = windowControllers[noteId] {
            existing.window?.orderFront(nil)
            return
        }
        
        let note = store.notes.first(where: { $0.id == noteId })
        let cardW = CGFloat(note?.width ?? Double(GridSnapManager.shared.cardWidth))
        let cardH = CGFloat(note?.height ?? Double(GridSnapManager.shared.cardHeight))
        let winW = cardW + 60
        let winH = cardH + 60
        
        let initialPoint = origin ?? CGPoint(x: 200, y: 300)
        let initialTopY = initialPoint.y + cardH + 30
        let panelOrigin = CGPoint(x: initialPoint.x - 30, y: initialTopY - winH)
        
        let panel = WidgetPanel(
            contentRect: NSRect(x: panelOrigin.x, y: panelOrigin.y, width: winW, height: winH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.noteId = noteId
        
        let isPinned = store.notes.first(where: { $0.id == noteId })?.isPinned ?? false
        panel.level = isPinned ? .floating : .init(Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        
        let rootView = WidgetRootView(noteId: noteId)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        panel.contentView = hostingView
        
        let controller = NSWindowController(window: panel)
        windowControllers[noteId] = controller
        panel.orderFront(nil)
    }
    
    public func setPinned(_ isPinned: Bool, for noteId: UUID) {
        guard let controller = windowControllers[noteId], let panel = controller.window else { return }
        panel.level = isPinned ? .floating : .init(Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        panel.orderFront(nil)
    }
    
    public func updateWindowSize(for noteId: UUID, newWidth: Double, newHeight: Double) {
        guard let controller = windowControllers[noteId], let panel = controller.window else { return }
        let currentFrame = panel.frame
        let targetPanelWidth = CGFloat(newWidth) + 60
        let targetPanelHeight = CGFloat(newHeight) + 60
        
        // Preserve top-left anchor when window height expands downwards
        let currentTopY = currentFrame.origin.y + currentFrame.height
        let newOriginY = currentTopY - targetPanelHeight
        
        if abs(currentFrame.width - targetPanelWidth) < 0.25 &&
           abs(currentFrame.height - targetPanelHeight) < 0.25 &&
           abs(currentFrame.origin.y - newOriginY) < 0.25 {
            return
        }
        
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: newOriginY,
            width: targetPanelWidth,
            height: targetPanelHeight
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(newFrame, display: true, animate: false)
        CATransaction.commit()
    }
    
    // MARK: - Dragging & Live Displacement Swapping
    public func beginDragging(noteId: UUID?) {
        guard noteId != nil else { return }
        lastPreviewTargetCol = nil
        lastPreviewTargetRow = nil
        dragStartSlots.removeAll()
        activePreviewSlots.removeAll()
        
        for note in store.notes {
            dragStartSlots[note.id] = (note.gridCol, note.gridRow)
            activePreviewSlots[note.id] = (note.gridCol, note.gridRow)
        }
    }
    
    public func updateDrag(noteId: UUID, screenMouse: CGPoint, panel: WidgetPanel) {
        guard let note = store.notes.first(where: { $0.id == noteId }) else { return }
        let cardW = CGFloat(note.width)
        let cardH = CGFloat(note.height)
        
        let (targetCol, targetRow) = GridSnapManager.shared.gridSlot(forPanelFrame: panel.frame)
        let targetSlotOrigin = GridSnapManager.shared.cardOrigin(forCol: targetCol, row: targetRow, cardHeight: cardH)
        GridSnapManager.shared.showGuide(at: targetSlotOrigin, width: cardW, height: cardH)
        
        if lastPreviewTargetCol != targetCol || lastPreviewTargetRow != targetRow {
            lastPreviewTargetCol = targetCol
            lastPreviewTargetRow = targetRow
            
            let newSlots = GridSnapManager.shared.solveNonOverlappingSlots(
                movingNoteId: noteId,
                targetCol: targetCol,
                targetRow: targetRow,
                allNotes: store.notes,
                currentSlots: dragStartSlots
            )
            
            self.activePreviewSlots = newSlots
            
            // Animate all OTHER panels smoothly to their preview displaced slots
            for otherNote in store.notes where otherNote.id != noteId {
                guard let targetSlot = newSlots[otherNote.id],
                      let controller = windowControllers[otherNote.id],
                      let otherPanel = controller.window as? WidgetPanel else { continue }
                
                let otherCardH = CGFloat(otherNote.height)
                let otherCardOrigin = GridSnapManager.shared.cardOrigin(forCol: targetSlot.col, row: targetSlot.row, cardHeight: otherCardH)
                let otherPanelOrigin = GridSnapManager.shared.panelOrigin(forCardOrigin: otherCardOrigin, cardHeight: otherCardH, panelHeight: otherPanel.frame.height)
                let targetFrame = NSRect(origin: otherPanelOrigin, size: otherPanel.frame.size)
                
                if otherPanel.frame.origin != otherPanelOrigin {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.22
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        context.allowsImplicitAnimation = true
                        otherPanel.animator().setFrame(targetFrame, display: true)
                    }
                }
            }
        }
    }
    
    public func endDrag(noteId: UUID, panel: WidgetPanel, didMove: Bool) {
        GridSnapManager.shared.hideGuide()
        
        guard let note = store.notes.first(where: { $0.id == noteId }) else { return }
        let cardH = CGFloat(note.height)
        
        if didMove {
            let (targetCol, targetRow) = GridSnapManager.shared.gridSlot(forPanelFrame: panel.frame)
            
            let finalSlots = GridSnapManager.shared.solveNonOverlappingSlots(
                movingNoteId: noteId,
                targetCol: targetCol,
                targetRow: targetRow,
                allNotes: store.notes,
                currentSlots: dragStartSlots
            )
            
            // 1. Animate the dragged panel directly into its snapped slot
            let draggedSlot = finalSlots[noteId] ?? (targetCol, targetRow)
            let draggedCardOrigin = GridSnapManager.shared.cardOrigin(forCol: draggedSlot.col, row: draggedSlot.row, cardHeight: cardH)
            let draggedPanelOrigin = GridSnapManager.shared.panelOrigin(forCardOrigin: draggedCardOrigin, cardHeight: cardH, panelHeight: panel.frame.height)
            let draggedTargetFrame = NSRect(origin: draggedPanelOrigin, size: panel.frame.size)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(draggedTargetFrame, display: true)
            }
            
            // 2. Commit all final grid slots & origins to NoteStore models and animate any remaining panels
            for (idx, n) in store.notes.enumerated() {
                if let slot = finalSlots[n.id] {
                    store.notes[idx].gridCol = slot.col
                    store.notes[idx].gridRow = slot.row
                    
                    let cardOrigin = GridSnapManager.shared.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: CGFloat(n.height))
                    store.notes[idx].positionX = cardOrigin.x
                    store.notes[idx].positionY = cardOrigin.y
                    
                    if n.id != noteId, let otherPanel = windowControllers[n.id]?.window as? WidgetPanel {
                        let otherPanelOrigin = GridSnapManager.shared.panelOrigin(forCardOrigin: cardOrigin, cardHeight: CGFloat(n.height), panelHeight: otherPanel.frame.height)
                        let otherTargetFrame = NSRect(origin: otherPanelOrigin, size: otherPanel.frame.size)
                        if otherPanel.frame.origin != otherPanelOrigin {
                            NSAnimationContext.runAnimationGroup { context in
                                context.duration = 0.20
                                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                                context.allowsImplicitAnimation = true
                                otherPanel.animator().setFrame(otherTargetFrame, display: true)
                            }
                        }
                    }
                }
            }
            SensoryFeedback.buttonClicked()
        }
    }
    
    public func spawnNewWidget(near origin: CGPoint? = nil) {
        let newId = UUID()
        let count = windowControllers.count
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let topY = visibleFrame.maxY - GridSnapManager.shared.edgeMarginY
        
        let spawnOrigin: CGPoint
        if let origin = origin {
            let nextX = origin.x + GridSnapManager.shared.cellWidth
            let targetPoint = CGPoint(x: nextX + (GridSnapManager.shared.cardWidth / 2), y: origin.y + (GridSnapManager.shared.cardHeight / 2))
            spawnOrigin = GridSnapManager.shared.snapOrigin(for: targetPoint)
        } else {
            let initialX = visibleFrame.minX + GridSnapManager.shared.edgeMarginX + (CGFloat(count) * GridSnapManager.shared.cellWidth)
            let initialY = topY - GridSnapManager.shared.cardHeight
            spawnOrigin = GridSnapManager.shared.snapOrigin(for: CGPoint(x: initialX + 140, y: initialY + 201))
        }
        
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newNote = NoteCard(
            id: newId,
            cardType: .tasks,
            title: "New Group",
            headerImagePath: nextWallpaper,
            items: [],
            positionX: spawnOrigin.x,
            positionY: spawnOrigin.y,
            width: 281,
            height: 364
        )
        
        store.notes.append(newNote)
        openWidgetWindow(for: newId, at: spawnOrigin)
    }
    
    public func spawnNewFreeformNoteWidget(near origin: CGPoint? = nil) {
        let newId = UUID()
        let count = windowControllers.count
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let topY = visibleFrame.maxY - GridSnapManager.shared.edgeMarginY
        
        let spawnOrigin: CGPoint
        if let origin = origin {
            let nextX = origin.x + GridSnapManager.shared.cellWidth
            let targetPoint = CGPoint(x: nextX + (GridSnapManager.shared.cardWidth / 2), y: origin.y + (GridSnapManager.shared.cardHeight / 2))
            spawnOrigin = GridSnapManager.shared.snapOrigin(for: targetPoint)
        } else {
            let initialX = visibleFrame.minX + GridSnapManager.shared.edgeMarginX + (CGFloat(count) * GridSnapManager.shared.cellWidth)
            let initialY = topY - GridSnapManager.shared.cardHeight
            spawnOrigin = GridSnapManager.shared.snapOrigin(for: CGPoint(x: initialX + 140, y: initialY + 201))
        }
        
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
        let newNote = NoteCard(
            id: newId,
            cardType: .notes,
            title: "Strategy",
            noteContent: NoteStore.defaultDemoNoteContent,
            pages: NoteStore.defaultDemoPages,
            activePageIndex: 0,
            headerImagePath: nextWallpaper,
            items: [],
            positionX: spawnOrigin.x,
            positionY: spawnOrigin.y,
            width: doubleCardWidth,
            height: 364
        )
        
        store.notes.append(newNote)
        openWidgetWindow(for: newId, at: spawnOrigin)
    }
    
    public func spawnNewFinderWidget(near origin: CGPoint? = nil) {
        let newId = UUID()
        let count = windowControllers.count
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let topY = visibleFrame.maxY - GridSnapManager.shared.edgeMarginY
        
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
        let doubleCardHeight: Double = 364.0 * 2.0 + 24.0
        
        let spawnOrigin: CGPoint
        if let origin = origin {
            let nextX = origin.x + GridSnapManager.shared.cellWidth
            let targetPoint = CGPoint(x: nextX + (CGFloat(doubleCardWidth) / 2), y: origin.y + (CGFloat(doubleCardHeight) / 2))
            spawnOrigin = GridSnapManager.shared.snapOrigin(for: targetPoint, cardWidth: CGFloat(doubleCardWidth), cardHeight: CGFloat(doubleCardHeight))
        } else {
            let initialX = visibleFrame.minX + GridSnapManager.shared.edgeMarginX + (CGFloat(count) * GridSnapManager.shared.cellWidth)
            let initialY = topY - CGFloat(doubleCardHeight)
            spawnOrigin = GridSnapManager.shared.snapOrigin(for: CGPoint(x: initialX + (CGFloat(doubleCardWidth) / 2), y: initialY + (CGFloat(doubleCardHeight) / 2)), cardWidth: CGFloat(doubleCardWidth), cardHeight: CGFloat(doubleCardHeight))
        }
        
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newNote = NoteCard(
            id: newId,
            cardType: .finder,
            title: "Finder AI",
            noteContent: "",
            headerImagePath: nextWallpaper,
            items: [],
            chatMessages: [],
            positionX: spawnOrigin.x,
            positionY: spawnOrigin.y,
            width: doubleCardWidth,
            height: doubleCardHeight
        )
        
        store.notes.append(newNote)
        openWidgetWindow(for: newId, at: spawnOrigin)
    }
    
    public func closeWidget(noteId: UUID) {
        if let controller = windowControllers[noteId] {
            controller.window?.close()
            windowControllers.removeValue(forKey: noteId)
        }
        store.deleteNote(id: noteId)
    }
    
    public func windowOrigin(for noteId: UUID) -> CGPoint? {
        guard let panel = windowControllers[noteId]?.window else { return nil }
        let panelOrigin = panel.frame.origin
        let cardBottomY = panelOrigin.y + panel.frame.height - 30 - GridSnapManager.shared.cardHeight
        return CGPoint(x: panelOrigin.x + 30, y: cardBottomY)
    }
    
    public func resetWidgetPositions() {
        for (index, note) in store.notes.enumerated() {
            let cardH = CGFloat(note.height)
            let targetOrigin = GridSnapManager.shared.cardOrigin(forCol: note.gridCol, row: note.gridRow, cardHeight: cardH)
            store.notes[index].positionX = targetOrigin.x
            store.notes[index].positionY = targetOrigin.y
            
            if let controller = windowControllers[note.id], let panel = controller.window {
                let otherPanelOrigin = GridSnapManager.shared.panelOrigin(forCardOrigin: targetOrigin, cardHeight: cardH, panelHeight: panel.frame.height)
                panel.setFrameOrigin(otherPanelOrigin)
            }
        }
    }
}
