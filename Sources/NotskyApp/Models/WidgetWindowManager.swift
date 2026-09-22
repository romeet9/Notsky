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
            ensureDefaultWorkspaceCards()
            setDemoData(enabled: AppSettings.shared.demoDataEnabled)
            return
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
        let targetWidth: Double = 281
        let targetHeight: Double = 364
        
        let slot: (col: Int, row: Int)
        if let origin = origin {
            let nextX = origin.x + GridSnapManager.shared.cellWidth
            let candidateSlot = GridSnapManager.shared.gridSlot(for: CGPoint(x: nextX + 140, y: origin.y + 182))
            // Verify if candidateSlot is free, else find next available
            let cSpan = GridSnapManager.shared.colSpan(for: targetWidth)
            let rSpan = GridSnapManager.shared.rowSpan(for: targetHeight)
            var isOccupied = false
            for n in store.notes {
                let nCol = n.gridCol
                let nRow = n.gridRow
                let nCSpan = GridSnapManager.shared.colSpan(for: n.width)
                let nRSpan = GridSnapManager.shared.rowSpan(for: n.height)
                if !(candidateSlot.col + cSpan <= nCol || candidateSlot.col >= nCol + nCSpan ||
                     candidateSlot.row + rSpan <= nRow || candidateSlot.row >= nRow + nRSpan) {
                    isOccupied = true
                    break
                }
            }
            slot = isOccupied ? GridSnapManager.shared.findNextAvailableSlot(cardWidth: targetWidth, cardHeight: targetHeight, existingNotes: store.notes) : candidateSlot
        } else {
            slot = GridSnapManager.shared.findNextAvailableSlot(cardWidth: targetWidth, cardHeight: targetHeight, existingNotes: store.notes)
        }
        
        let spawnOrigin = GridSnapManager.shared.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: CGFloat(targetHeight))
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newNote = NoteCard(
            id: newId,
            cardType: .tasks,
            title: "New Group",
            headerImagePath: nextWallpaper,
            items: [],
            gridCol: slot.col,
            gridRow: slot.row,
            positionX: spawnOrigin.x,
            positionY: spawnOrigin.y,
            width: targetWidth,
            height: targetHeight
        )
        
        store.notes.append(newNote)
        openWidgetWindow(for: newId, at: spawnOrigin)
    }
    
    public func spawnNewFreeformNoteWidget(near origin: CGPoint? = nil) {
        let newId = UUID()
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
        let targetHeight: Double = 364.0
        
        let slot = GridSnapManager.shared.findNextAvailableSlot(cardWidth: doubleCardWidth, cardHeight: targetHeight, existingNotes: store.notes)
        let spawnOrigin = GridSnapManager.shared.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: CGFloat(targetHeight))
        
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newNote = NoteCard(
            id: newId,
            cardType: .notes,
            title: "Strategy",
            noteContent: NoteStore.defaultDemoNoteContent,
            pages: NoteStore.defaultDemoPages,
            activePageIndex: 0,
            headerImagePath: nextWallpaper,
            items: [],
            gridCol: slot.col,
            gridRow: slot.row,
            positionX: spawnOrigin.x,
            positionY: spawnOrigin.y,
            width: doubleCardWidth,
            height: targetHeight
        )
        
        store.notes.append(newNote)
        openWidgetWindow(for: newId, at: spawnOrigin)
    }
    
    public func spawnNewFinderWidget(near origin: CGPoint? = nil) {
        let newId = UUID()
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
        let doubleCardHeight: Double = 364.0 * 2.0 + 24.0
        
        let slot = GridSnapManager.shared.findNextAvailableSlot(cardWidth: doubleCardWidth, cardHeight: doubleCardHeight, existingNotes: store.notes)
        let spawnOrigin = GridSnapManager.shared.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: CGFloat(doubleCardHeight))
        
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newNote = NoteCard(
            id: newId,
            cardType: .finder,
            title: "Finder AI",
            noteContent: "",
            headerImagePath: nextWallpaper,
            items: [],
            chatMessages: [],
            gridCol: slot.col,
            gridRow: slot.row,
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
            controller.window?.contentView = nil
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
    
    public func clearWorkspace() {
        for (_, controller) in windowControllers {
            controller.window?.contentView = nil
            controller.window?.close()
        }
        windowControllers.removeAll()
        store.notes.removeAll()
    }
    
    public func ensureDefaultWorkspaceCards() {
        if store.notes.count == 4 {
            return
        }
        
        clearWorkspace()
        
        let packs = WallpaperPackManager.builtInPacks()
        let items = packs.first?.items ?? []
        
        let w0 = items.indices.contains(0) ? items[0].path : WallpaperPackManager.shared.nextWallpaperPath()
        let w1 = items.indices.contains(4) ? items[4].path : (items.indices.contains(1) ? items[1].path : WallpaperPackManager.shared.nextWallpaperPath())
        let w2 = items.indices.contains(2) ? items[2].path : WallpaperPackManager.shared.nextWallpaperPath()
        let w3 = items.indices.contains(1) ? items[1].path : (items.indices.contains(3) ? items[3].path : WallpaperPackManager.shared.nextWallpaperPath())
        
        let card1 = NoteCard(
            id: UUID(),
            cardType: .tasks,
            title: "Tasks",
            headerImagePath: w0,
            items: [],
            gridCol: 0,
            gridRow: 0,
            width: 281,
            height: 364,
            timerDuration: 25 * 60,
            timeRemaining: 25 * 60,
            isTimerRunning: false
        )
        
        let card2 = NoteCard(
            id: UUID(),
            cardType: .tasks,
            title: "Tasks",
            headerImagePath: w1,
            items: [],
            gridCol: 1,
            gridRow: 0,
            width: 281,
            height: 364,
            timerDuration: 25 * 60,
            timeRemaining: 25 * 60,
            isTimerRunning: false
        )
        
        let card3 = NoteCard(
            id: UUID(),
            cardType: .notes,
            title: "Notes",
            noteContent: "",
            pages: [NotePage(title: "Untitled", content: "")],
            activePageIndex: 0,
            headerImagePath: w2,
            items: [],
            gridCol: 0,
            gridRow: 1,
            width: 586,
            height: 364
        )
        
        let card4 = NoteCard(
            id: UUID(),
            cardType: .finder,
            title: "notskyai",
            noteContent: "",
            headerImagePath: w3,
            items: [],
            chatMessages: [],
            gridCol: 2,
            gridRow: 0,
            width: 586,
            height: 752
        )
        
        store.notes = [card1, card2, card3, card4]
        
        for (index, note) in store.notes.enumerated() {
            let cardH = CGFloat(note.height)
            let origin = GridSnapManager.shared.cardOrigin(forCol: note.gridCol, row: note.gridRow, cardHeight: cardH)
            store.notes[index].positionX = origin.x
            store.notes[index].positionY = origin.y
            openWidgetWindow(for: note.id, at: origin)
        }
    }
    
    public func setDemoData(enabled: Bool) {
        ensureDefaultWorkspaceCards()
        
        if enabled {
            // Populate demo data into the cards
            if store.notes.indices.contains(0) {
                store.notes[0].title = "Design Iterations"
                store.notes[0].items = [
                    NoteItem(text: "Explore liquid-glass refraction shaders", isCompleted: true),
                    NoteItem(text: "Refine superellipse continuous corners (40pt)", isCompleted: true),
                    NoteItem(text: "Tune dynamic wallpaper luminance tinting", isCompleted: true),
                    NoteItem(text: "Test multi-monitor cursor magnetic snapping", isCompleted: false),
                    NoteItem(text: "Polish over-dock slide shelf animations", isCompleted: false)
                ]
            }
            if store.notes.indices.contains(1) {
                store.notes[1].title = "Launch Checklist"
                store.notes[1].items = [
                    NoteItem(text: "Finalize macOS AppIcon & Dock integration", isCompleted: true),
                    NoteItem(text: "Verify template menu bar icon optical height", isCompleted: true),
                    NoteItem(text: "Test slide-up drawer over sticky dock", isCompleted: true),
                    NoteItem(text: "Render 4K UI widget showcase mockups", isCompleted: true),
                    NoteItem(text: "Ship v1.0.0 release build to GitHub", isCompleted: false)
                ]
                store.notes[1].timeRemaining = 18 * 60 + 42
                store.notes[1].isTimerRunning = true
            }
            if store.notes.indices.contains(2) {
                let strategyContent = """
**Core Architecture Principles**

• **Zero-Latency Spatial Physics**: Native AppKit NSPanel windows with hardware acceleration.

• **Dynamic Visual Cohesion**: Background-aware chromatic adaptation.

• **Spatial Canvas Freedom**: Independent movable widgets with magnetic snapping.
"""
                let ideasContent = """
**Product Ideas & Brainstorming**

• **Multi-Tab Cards**: Keep workspace tidy with tabbed desktop cards.
• **Trackpad Gestures**: Swipe smoothly between note tabs.
• **Rich 4K Cards**: Instant wallpaper exports for sharing on social platforms.
"""
                let snippetsContent = """
**Developer & Design Snippets**

• `git commit -m "feat: multi-tab quick notes"`
• `swift build -c release`
• **Material Formula**: `.ultraThinMaterial` + `specularBorderGradient`
"""
                store.notes[2].title = "Strategy & Notes"
                store.notes[2].noteContent = strategyContent
                store.notes[2].pages = [
                    NotePage(title: "Strategy", content: strategyContent),
                    NotePage(title: "Ideas", content: ideasContent),
                    NotePage(title: "Snippets", content: snippetsContent)
                ]
                store.notes[2].activePageIndex = 0
            }
            if store.notes.indices.contains(3) {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let sampleFiles = [
                    FinderFileItem(name: "Q3_Product_Roadmap.pdf", path: "\(home)/Documents/Q3_Product_Roadmap.pdf", fileSize: "2.4 MB", fileType: "PDF Document", summary: "Contains spatial physics engine deliverables & Q3 milestones", formattedDate: "Today, 2:15 PM"),
                    FinderFileItem(name: "Design_System_Tokens.pdf", path: "\(home)/Documents/Design_System_Tokens.pdf", fileSize: "5.1 MB", fileType: "PDF Document", summary: "Mac OS optical depth, continuous corner radius & materials spec", formattedDate: "Yesterday"),
                    FinderFileItem(name: "Notsky_Release_Notes.md", path: "\(home)/Documents/Notsky_Release_Notes.md", fileSize: "14 KB", fileType: "Markdown", summary: "v1.0.0 production release changelog and installer build steps", formattedDate: "Sep 20, 2026")
                ]
                store.notes[3].title = "notskyai"
                store.notes[3].chatMessages = [
                    ChatMessage(role: "user", content: "Find recent architectural specs and roadmap PDFs"),
                    ChatMessage(role: "assistant", content: "I indexed your local documents and located 3 relevant design and engineering files:", attachedFiles: sampleFiles)
                ]
            }
        } else {
            // Reset contents to empty / blank, keeping the cards visible
            if store.notes.indices.contains(0) {
                store.notes[0].title = "Tasks"
                store.notes[0].items = []
                store.notes[0].isTimerRunning = false
                store.notes[0].timeRemaining = store.notes[0].timerDuration
            }
            if store.notes.indices.contains(1) {
                store.notes[1].title = "Tasks"
                store.notes[1].items = []
                store.notes[1].isTimerRunning = false
                store.notes[1].timeRemaining = store.notes[1].timerDuration
            }
            if store.notes.indices.contains(2) {
                store.notes[2].title = "Notes"
                store.notes[2].noteContent = ""
                store.notes[2].pages = [NotePage(title: "Untitled", content: "")]
                store.notes[2].activePageIndex = 0
            }
            if store.notes.indices.contains(3) {
                store.notes[3].title = "notskyai"
                store.notes[3].chatMessages = []
            }
        }
        
        store.saveToDisk()
        SensoryFeedback.buttonClicked()
    }
    
    public func fillDemoData() {
        setDemoData(enabled: true)
    }
}
