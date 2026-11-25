import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Manager

@MainActor
@Observable
public final class WidgetWindowManager: NSObject {
    public static let shared = WidgetWindowManager()
    
    @ObservationIgnored private var windowControllers: [UUID: NSWindowController] = [:]
    public var store = NoteStore()
    
    @ObservationIgnored private var lastPreviewTargetCol: Int? = nil
    @ObservationIgnored private var lastPreviewTargetRow: Int? = nil
    @ObservationIgnored private var lastPreviewScreenKey: String? = nil
    @ObservationIgnored private var dragStartSlots: [UUID: (col: Int, row: Int)] = [:]
    @ObservationIgnored private var activePreviewSlots: [UUID: (col: Int, row: Int)] = [:]
    
    /// Display-only slots for cards whose saved screen is disconnected and that would otherwise
    /// overlap cards on the primary display. Never persisted (saved gridCol/gridRow stay intact).
    @ObservationIgnored private var displaySlotOverrides: [UUID: (col: Int, row: Int)] = [:]
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Per-note screen helpers
    private func screen(for note: NoteCard) -> NSScreen? {
        GridSnapManager.shared.screen(for: note.screenID)
    }
    
    private func slot(for note: NoteCard) -> (col: Int, row: Int) {
        displaySlotOverrides[note.id] ?? (note.gridCol, note.gridRow)
    }
    
    private func cardOrigin(for note: NoteCard) -> CGPoint {
        let s = slot(for: note)
        return GridSnapManager.shared.cardOrigin(forCol: s.col, row: s.row, cardHeight: CGFloat(note.height), screen: screen(for: note))
    }
    
    public func start() {
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.relayoutAllWidgets()
                }
            }
        }
        
        if store.notes.isEmpty {
            setDemoData(enabled: AppSettings.shared.demoDataEnabled)
            return
        }
        
        relayoutAllWidgets()
    }
    
    /// Re-lays out every widget onto its own screen. Cards whose display is gone fall back to the
    /// primary display but keep their saved screenID so they return when the display is re-plugged.
    public func relayoutAllWidgets() {
        let grid = GridSnapManager.shared
        displaySlotOverrides.removeAll()
        
        // Cards sitting on a connected display keep their saved slot; orphans are resolved afterwards.
        var placedByScreen: [String: [NoteCard]] = [:]
        var orphans: [NoteCard] = []
        // Native cards are placed in reading order; any card overlapping an earlier one
        // (e.g. a card wider than its saved span) is moved to the next free slot and saved.
        let readingOrder = store.notes.indices.sorted {
            let a = store.notes[$0], b = store.notes[$1]
            return a.gridRow != b.gridRow ? a.gridRow < b.gridRow : a.gridCol < b.gridCol
        }
        for index in readingOrder {
            let note = store.notes[index]
            let resolved = grid.resolvedScreenID(note.screenID)
            let isNative = note.screenID == nil || note.screenID == resolved
            if isNative {
                let key = resolved ?? ""
                let placed = placedByScreen[key] ?? []
                if !grid.isSlotFree(col: note.gridCol, row: note.gridRow, cardWidth: note.width, cardHeight: note.height, existingNotes: placed) {
                    let free = grid.findNextAvailableSlot(cardWidth: note.width, cardHeight: note.height, existingNotes: placed)
                    store.notes[index].gridCol = free.col
                    store.notes[index].gridRow = free.row
                }
                placedByScreen[key, default: []].append(store.notes[index])
            } else {
                orphans.append(note)
            }
        }
        for orphan in orphans {
            let key = grid.resolvedScreenID(orphan.screenID) ?? ""
            var placed = placedByScreen[key] ?? []
            var candidate = orphan
            if !grid.isSlotFree(col: orphan.gridCol, row: orphan.gridRow, cardWidth: orphan.width, cardHeight: orphan.height, existingNotes: placed) {
                let free = grid.findNextAvailableSlot(cardWidth: orphan.width, cardHeight: orphan.height, existingNotes: placed)
                candidate.gridCol = free.col
                candidate.gridRow = free.row
                displaySlotOverrides[orphan.id] = free
            }
            placed.append(candidate)
            placedByScreen[key] = placed
        }
        
        for index in store.notes.indices {
            let note = store.notes[index]
            let origin = cardOrigin(for: note)
            store.notes[index].positionX = origin.x
            store.notes[index].positionY = origin.y
            if let panel = windowControllers[note.id]?.window {
                let panelOrigin = grid.panelOrigin(forCardOrigin: origin, cardHeight: CGFloat(note.height), panelHeight: panel.frame.height)
                panel.setFrameOrigin(panelOrigin)
            } else {
                openWidgetWindow(for: note.id, at: origin)
            }
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
        syncNowPlayingService()
        syncLinearService()
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
        lastPreviewScreenKey = nil
        dragStartSlots.removeAll()
        activePreviewSlots.removeAll()
        
        for note in store.notes {
            let s = slot(for: note)
            dragStartSlots[note.id] = s
            activePreviewSlots[note.id] = s
        }
    }
    
    public func updateDrag(noteId: UUID, screenMouse: CGPoint, panel: WidgetPanel) {
        guard let note = store.notes.first(where: { $0.id == noteId }) else { return }
        let cardW = CGFloat(note.width)
        let cardH = CGFloat(note.height)
        
        let grid = GridSnapManager.shared
        let targetScreen = grid.targetScreen(mouse: NSEvent.mouseLocation, panelFrame: panel.frame)
        let targetScreenID = targetScreen?.displayUUID
        let (targetCol, targetRow) = grid.gridSlot(forPanelFrame: panel.frame, screen: targetScreen)
        let targetSlotOrigin = grid.cardOrigin(forCol: targetCol, row: targetRow, cardHeight: cardH, screen: targetScreen)
        grid.showGuide(at: targetSlotOrigin, width: cardW, height: cardH)
        
        let screenKey = targetScreenID ?? ""
        if lastPreviewTargetCol != targetCol || lastPreviewTargetRow != targetRow || lastPreviewScreenKey != screenKey {
            lastPreviewTargetCol = targetCol
            lastPreviewTargetRow = targetRow
            lastPreviewScreenKey = screenKey
            
            // Only cards on the target display take part in the solve.
            let targetNotes = grid.notes(store.notes, onScreen: targetScreenID).filter { $0.id != noteId }
            let newSlots = grid.solveNonOverlappingSlots(
                movingNoteId: noteId,
                targetCol: targetCol,
                targetRow: targetRow,
                allNotes: [note] + targetNotes,
                currentSlots: dragStartSlots
            )
            
            self.activePreviewSlots = newSlots
            
            // Animate all OTHER panels to their preview slots (or back to their start slot if not displaced)
            for otherNote in store.notes where otherNote.id != noteId {
                guard let targetSlot = newSlots[otherNote.id] ?? dragStartSlots[otherNote.id],
                      let controller = windowControllers[otherNote.id],
                      let otherPanel = controller.window as? WidgetPanel else { continue }
                
                let otherCardH = CGFloat(otherNote.height)
                let otherCardOrigin = grid.cardOrigin(forCol: targetSlot.col, row: targetSlot.row, cardHeight: otherCardH, screen: screen(for: otherNote))
                let otherPanelOrigin = GridSnapManager.shared.panelOrigin(forCardOrigin: otherCardOrigin, cardHeight: otherCardH, panelHeight: otherPanel.frame.height)
                let targetFrame = NSRect(origin: otherPanelOrigin, size: otherPanel.frame.size)
                
                if otherPanel.frame.origin != otherPanelOrigin {
                    Motion.setFrame(otherPanel, to: targetFrame, duration: 0.22)
                }
            }
        }
    }
    
    public func endDrag(noteId: UUID, panel: WidgetPanel, didMove: Bool) {
        GridSnapManager.shared.hideGuide()
        
        guard let note = store.notes.first(where: { $0.id == noteId }) else { return }
        let cardH = CGFloat(note.height)
        
        if didMove {
            let grid = GridSnapManager.shared
            let targetScreen = grid.targetScreen(mouse: NSEvent.mouseLocation, panelFrame: panel.frame)
            let targetScreenID = targetScreen?.displayUUID
            let (targetCol, targetRow) = grid.gridSlot(forPanelFrame: panel.frame, screen: targetScreen)
            
            let targetNotes = grid.notes(store.notes, onScreen: targetScreenID).filter { $0.id != noteId }
            let finalSlots = grid.solveNonOverlappingSlots(
                movingNoteId: noteId,
                targetCol: targetCol,
                targetRow: targetRow,
                allNotes: [note] + targetNotes,
                currentSlots: dragStartSlots
            )
            
            // 1. Animate the dragged panel directly into its snapped slot
            let draggedSlot = finalSlots[noteId] ?? (targetCol, targetRow)
            let draggedCardOrigin = grid.cardOrigin(forCol: draggedSlot.col, row: draggedSlot.row, cardHeight: cardH, screen: targetScreen)
            let draggedPanelOrigin = GridSnapManager.shared.panelOrigin(forCardOrigin: draggedCardOrigin, cardHeight: cardH, panelHeight: panel.frame.height)
            let draggedTargetFrame = NSRect(origin: draggedPanelOrigin, size: panel.frame.size)
            
            Motion.setFrame(panel, to: draggedTargetFrame, duration: 0.20)
            
            // 2. Commit all final grid slots & origins to NoteStore models and animate any remaining panels
            for (idx, n) in store.notes.enumerated() {
                if let slot = finalSlots[n.id] {
                    store.notes[idx].gridCol = slot.col
                    store.notes[idx].gridRow = slot.row
                    if n.id == noteId {
                        store.notes[idx].screenID = targetScreenID
                    }
                    
                    let cardOrigin = grid.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: CGFloat(n.height), screen: targetScreen)
                    store.notes[idx].positionX = cardOrigin.x
                    store.notes[idx].positionY = cardOrigin.y
                    
                    if n.id != noteId, let otherPanel = windowControllers[n.id]?.window as? WidgetPanel {
                        let otherPanelOrigin = grid.panelOrigin(forCardOrigin: cardOrigin, cardHeight: CGFloat(n.height), panelHeight: otherPanel.frame.height)
                        let otherTargetFrame = NSRect(origin: otherPanelOrigin, size: otherPanel.frame.size)
                        if otherPanel.frame.origin != otherPanelOrigin {
                            Motion.setFrame(otherPanel, to: otherTargetFrame, duration: 0.20)
                        }
                    }
                }
            }
            for id in finalSlots.keys { displaySlotOverrides.removeValue(forKey: id) }
            SensoryFeedback.buttonClicked()
        }
    }
    
    /// Picks the first free slot on the screen under the mouse, creates the card there and opens its window.
    private func placeAndOpen(
        width: Double,
        height: Double,
        preferredCandidate: ((NSScreen?) -> (col: Int, row: Int)?)? = nil,
        make: (_ id: UUID, _ slot: (col: Int, row: Int), _ origin: CGPoint, _ screenID: String?) -> NoteCard
    ) {
        let grid = GridSnapManager.shared
        let screen = grid.screenUnderMouse()
        let screenID = screen?.displayUUID
        let sameScreenNotes = grid.notes(store.notes, onScreen: screenID)
        
        var slot = grid.findNextAvailableSlot(cardWidth: width, cardHeight: height, existingNotes: sameScreenNotes)
        if let candidate = preferredCandidate?(screen),
           grid.isSlotFree(col: candidate.col, row: candidate.row, cardWidth: width, cardHeight: height, existingNotes: sameScreenNotes) {
            slot = candidate
        }
        
        let id = UUID()
        let origin = grid.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: CGFloat(height), screen: screen)
        let note = make(id, slot, origin, screenID)
        store.notes.append(note)
        openWidgetWindow(for: id, at: origin)
    }
    
    public func spawnNewWidget(near origin: CGPoint? = nil) {
        let targetWidth: Double = 281
        let targetHeight: Double = 364
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        placeAndOpen(
            width: targetWidth,
            height: targetHeight,
            preferredCandidate: { screen in
                guard let origin = origin, let screen = screen, screen.frame.contains(origin) else { return nil }
                let nextX = origin.x + GridSnapManager.shared.cellWidth
                return GridSnapManager.shared.gridSlot(for: CGPoint(x: nextX + 140, y: origin.y + 182), screen: screen)
            },
            make: { id, slot, origin, screenID in
                NoteCard(
                    id: id,
                    cardType: .tasks,
                    title: "New Group",
                    headerImagePath: nextWallpaper,
                    items: [],
                    gridCol: slot.col,
                    gridRow: slot.row,
                    positionX: origin.x,
                    positionY: origin.y,
                    width: targetWidth,
                    height: targetHeight,
                    screenID: screenID
                )
            }
        )
    }
    
    public func spawnNewFreeformNoteWidget(near origin: CGPoint? = nil) {
        let cardWidth: Double = 586.0
        let targetHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        placeAndOpen(width: cardWidth, height: targetHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .notes,
                title: "Strategy",
                noteContent: NoteStore.defaultDemoNoteContent,
                pages: NoteStore.defaultDemoPages,
                activePageIndex: 0,
                headerImagePath: nextWallpaper,
                items: [],
                gridCol: slot.col,
                gridRow: slot.row,
                positionX: origin.x,
                positionY: origin.y,
                width: cardWidth,
                height: targetHeight,
                screenID: screenID
            )
        }
    }
    
    public func spawnNewFinderWidget(near origin: CGPoint? = nil) {
        let cardWidth: Double = 360.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .finder,
                title: "Finder AI",
                noteContent: "",
                headerImagePath: nextWallpaper,
                items: [],
                gridCol: slot.col,
                gridRow: slot.row,
                positionX: origin.x,
                positionY: origin.y,
                width: cardWidth,
                height: cardHeight,
                screenID: screenID
            )
        }
    }
    
    public func spawnNewFoldersWidget(near origin: CGPoint? = nil) {
        let cardWidth: Double = 360.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .folders,
                title: "Folders",
                noteContent: "",
                headerImagePath: nextWallpaper,
                items: [],
                chatMessages: [],
                gridCol: slot.col,
                gridRow: slot.row,
                positionX: origin.x,
                positionY: origin.y,
                width: cardWidth,
                height: cardHeight,
                screenID: screenID
            )
        }
    }
    
    public func spawnNewNowPlayingWidget(near origin: CGPoint? = nil) {
        let cardWidth: Double = 281.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .nowPlaying,
                title: "Now Playing",
                noteContent: "",
                headerImagePath: nextWallpaper,
                items: [],
                chatMessages: [],
                gridCol: slot.col,
                gridRow: slot.row,
                positionX: origin.x,
                positionY: origin.y,
                width: cardWidth,
                height: cardHeight,
                screenID: screenID
            )
        }
    }
    
    public func spawnNewLinearWidget(near origin: CGPoint? = nil) {
        let cardWidth: Double = 586.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .linear,
                title: "Linear",
                noteContent: "",
                headerImagePath: nextWallpaper,
                items: [],
                chatMessages: [],
                gridCol: slot.col,
                gridRow: slot.row,
                positionX: origin.x,
                positionY: origin.y,
                width: cardWidth,
                height: cardHeight,
                screenID: screenID
            )
        }
    }
    
    /// The shared Linear service runs only while at least one Linear card exists.
    private func syncLinearService() {
        LinearService.shared.setActive(store.notes.contains { $0.cardType == .linear })
    }
    
    /// The shared music service runs only while at least one Now Playing card exists.
    private func syncNowPlayingService() {
        NowPlayingService.shared.setActive(store.notes.contains { $0.cardType == .nowPlaying })
    }
    
    public func focusWidget(for noteId: UUID) {
        if let controller = windowControllers[noteId], let window = controller.window {
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)
            if Motion.reduced { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 0.7
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.15
                    window.animator().alphaValue = 1.0
                }
            }
        } else if let note = store.notes.first(where: { $0.id == noteId }) {
            openWidgetWindow(for: noteId, at: cardOrigin(for: note))
        }
    }
    
    public func closeWidget(noteId: UUID) {
        if let controller = windowControllers[noteId] {
            controller.window?.contentView = nil
            controller.window?.close()
            windowControllers.removeValue(forKey: noteId)
        }
        store.deleteNote(id: noteId)
        syncNowPlayingService()
        syncLinearService()
    }
    
    public func windowOrigin(for noteId: UUID) -> CGPoint? {
        guard let panel = windowControllers[noteId]?.window else { return nil }
        let panelOrigin = panel.frame.origin
        let cardBottomY = panelOrigin.y + panel.frame.height - 30 - GridSnapManager.shared.cardHeight
        return CGPoint(x: panelOrigin.x + 30, y: cardBottomY)
    }
    
    public func resetWidgetPositions() {
        relayoutAllWidgets()
    }
    
    public func clearWorkspace() {
        for (_, controller) in windowControllers {
            controller.window?.contentView = nil
            controller.window?.close()
        }
        windowControllers.removeAll()
        store.notes.removeAll()
        syncNowPlayingService()
        syncLinearService()
    }
    
    /// Asks for confirmation, backs up the store file, then clears every card.
    public func confirmAndClearWorkspace() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear Workspace?")
        alert.informativeText = String(localized: "This removes all cards and their contents from your desktop. A backup of your workspace file is saved first.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Clear Workspace"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        store.saveToDisk() // flush pending edits so the backup is current
        if NoteStore.backupStoreFile(reason: "pre-clear") == nil {
            let failure = NSAlert()
            failure.messageText = String(localized: "Backup failed")
            failure.informativeText = String(localized: "Could not back up the workspace file, so the workspace was not cleared.")
            failure.alertStyle = .critical
            failure.runModal()
            return
        }
        clearWorkspace()
    }
    
    /// Fills the default cards, but only when the workspace is empty. Never touches existing notes.
    public func ensureDefaultWorkspaceCards() {
        guard store.notes.isEmpty else { return }
        
        let primaryID = GridSnapManager.shared.primaryScreen?.displayUUID
        
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
            width: 360,
            height: 364
        )
        
        store.notes = [card1, card2, card3, card4]
        
        for index in store.notes.indices {
            store.notes[index].screenID = primaryID
            let note = store.notes[index]
            let origin = cardOrigin(for: note)
            store.notes[index].positionX = origin.x
            store.notes[index].positionY = origin.y
            openWidgetWindow(for: note.id, at: origin)
        }
    }
    
    /// Fills sample content, but only into a freshly created (previously empty) workspace.
    /// Existing user notes are never cleared, blanked or overwritten.
    public func setDemoData(enabled: Bool) {
        let wasEmpty = store.notes.isEmpty
        ensureDefaultWorkspaceCards()
        guard wasEmpty else { return }
        
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
        }
        
        store.saveToDisk()
        SensoryFeedback.buttonClicked()
    }
    
    public func fillDemoData() {
        setDemoData(enabled: true)
    }
}
