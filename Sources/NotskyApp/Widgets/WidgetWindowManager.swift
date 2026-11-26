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
                    self?.relayoutAllWidgets(animated: true)
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
    public func relayoutAllWidgets(animated: Bool = false) {
        let grid = GridSnapManager.shared
        grid.invalidateMetrics()
        displaySlotOverrides.removeAll()
        
        var placedByScreen: [String: [NoteCard]] = [:]
        // Natives first (saved display connected), orphans (display gone) after; each in reading order.
        let readingOrder = store.notes.indices.sorted {
            let a = store.notes[$0], b = store.notes[$1]
            return a.gridRow != b.gridRow ? a.gridRow < b.gridRow : a.gridCol < b.gridCol
        }
        func isNative(_ n: NoteCard) -> Bool {
            n.screenID == nil || n.screenID == grid.resolvedScreenID(n.screenID)
        }
        let ordered = readingOrder.filter { isNative(store.notes[$0]) } + readingOrder.filter { !isNative(store.notes[$0]) }
        
        for index in ordered {
            var note = store.notes[index]
            let sp = grid.spans(of: note)
            let orphan = !isNative(note)
            let home = grid.screen(for: note.screenID)
            let homeKey = home?.displayUUID ?? ""
            let homePlaced = placedByScreen[homeKey] ?? []
            var finalKey = homeKey
            var slot = (col: note.gridCol, row: note.gridRow)
            
            if !grid.isSlotFree(col: slot.col, row: slot.row, cSpan: sp.c, rSpan: sp.r, existingNotes: homePlaced, screen: home) {
                if let f = grid.findFreeSlot(cSpan: sp.c, rSpan: sp.r, existingNotes: homePlaced, screen: home) {
                    slot = f
                } else {
                    var found = false
                    for other in NSScreen.screens where (other.displayUUID ?? "") != homeKey {
                        let key = other.displayUUID ?? ""
                        if let f = grid.findFreeSlot(cSpan: sp.c, rSpan: sp.r, existingNotes: placedByScreen[key] ?? [], screen: other) {
                            slot = f
                            finalKey = key
                            found = true
                            break
                        }
                    }
                    if !found {
                        slot = grid.lastFittingSlot(cSpan: sp.c, rSpan: sp.r, screen: home)
                    }
                }
            }
            
            let moved = slot.col != note.gridCol || slot.row != note.gridRow
            if finalKey != homeKey {
                store.notes[index].screenID = finalKey
                store.notes[index].gridCol = slot.col
                store.notes[index].gridRow = slot.row
            } else if moved {
                if orphan {
                    displaySlotOverrides[note.id] = slot
                } else {
                    store.notes[index].gridCol = slot.col
                    store.notes[index].gridRow = slot.row
                }
            }
            note.gridCol = slot.col
            note.gridRow = slot.row
            placedByScreen[finalKey, default: []].append(note)
        }
        
        applyLayout(animated: animated)
    }
    
    /// Effective layout: base spans are the source of truth; each screen then expands cards into empty
    /// neighbouring cells. Effective sizes are display-only (written to note.width/height, never to spans).
    public func applyLayout(animated: Bool) {
        let grid = GridSnapManager.shared
        var groups: [String: (screen: NSScreen?, idx: [Int])] = [:]
        for i in store.notes.indices {
            let sc = screen(for: store.notes[i])
            groups[sc?.displayUUID ?? "", default: (sc, [])].idx.append(i)
        }
        for (_, group) in groups {
            let notes = group.idx.map { store.notes[$0] }
            var slots: [UUID: (col: Int, row: Int)] = [:]
            for n in notes { slots[n.id] = slot(for: n) }
            let eff = grid.expandedSpans(for: notes, slots: slots, screen: group.screen)
            for i in group.idx {
                let n = store.notes[i]
                let s = eff[n.id] ?? grid.spans(of: n)
                let size = grid.cardSize(cSpan: s.c, rSpan: s.r, screen: group.screen)
                let sl = slots[n.id] ?? (n.gridCol, n.gridRow)
                let origin = grid.cardOrigin(forCol: sl.col, row: sl.row, cardHeight: size.height, screen: group.screen)
                if abs(n.width - Double(size.width)) > 0.01 { store.notes[i].width = Double(size.width) }
                if abs(n.height - Double(size.height)) > 0.01 { store.notes[i].height = Double(size.height) }
                if abs(n.positionX - Double(origin.x)) > 0.01 { store.notes[i].positionX = origin.x }
                if abs(n.positionY - Double(origin.y)) > 0.01 { store.notes[i].positionY = origin.y }
                
                guard let panel = windowControllers[n.id]?.window else {
                    openWidgetWindow(for: n.id, at: origin)
                    continue
                }
                let panelSize = CGSize(width: size.width + 60, height: size.height + 60)
                let po = grid.panelOrigin(forCardOrigin: origin, cardHeight: size.height, panelHeight: panelSize.height)
                let target = NSRect(origin: po, size: panelSize)
                let cur = panel.frame
                if abs(cur.origin.x - target.origin.x) < 0.25 && abs(cur.origin.y - target.origin.y) < 0.25
                    && abs(cur.width - target.width) < 0.25 && abs(cur.height - target.height) < 0.25 { continue }
                if animated {
                    Motion.setFrame(panel, to: target, duration: 0.25)
                } else {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    panel.setFrame(target, display: true, animate: false)
                    CATransaction.commit()
                }
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
        syncVoiceOpenService()
    }
    
    public func setPinned(_ isPinned: Bool, for noteId: UUID) {
        guard let controller = windowControllers[noteId], let panel = controller.window else { return }
        panel.level = isPinned ? .floating : .init(Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        panel.orderFront(nil)
    }
    
    /// Edge-drag resize: converts the dragged pixel size into grid spans (the source of truth), then re-lays out.
    public func updateWindowSize(for noteId: UUID, newWidth: Double, newHeight: Double) {
        guard let idx = store.notes.firstIndex(where: { $0.id == noteId }) else { return }
        let grid = GridSnapManager.shared
        let note = store.notes[idx]
        let home = screen(for: note)
        let want = grid.spans(forPixelWidth: newWidth, height: newHeight, screen: home)
        let cur = grid.spans(of: note)
        let sl = slot(for: note)
        let others = grid.notes(store.notes, onScreen: home?.displayUUID).filter { $0.id != noteId }
        let m = grid.metrics(for: home)
        
        func tryFit(_ c: Int, _ r: Int) -> (col: Int, row: Int)? {
            let col = max(0, min(sl.col, m.cols - c))
            let row = max(0, min(sl.row, m.rows - r))
            return grid.isSlotFree(col: col, row: row, cSpan: c, rSpan: r, existingNotes: others, screen: home) ? (col, row) : nil
        }
        let options = [(want.c, want.r), (want.c, cur.r), (cur.c, want.r)]
        for o in options {
            guard let pos = tryFit(o.0, o.1) else { continue }
            if o.0 != cur.c || o.1 != cur.r || pos.col != note.gridCol || pos.row != note.gridRow {
                store.notes[idx].colSpan = o.0
                store.notes[idx].rowSpan = o.1
                store.notes[idx].gridCol = pos.col
                store.notes[idx].gridRow = pos.row
                displaySlotOverrides.removeValue(forKey: noteId)
                applyLayout(animated: true)
            }
            return
        }
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
        let grid = GridSnapManager.shared
        let sp = grid.spans(of: note)
        let targetScreen = grid.targetScreen(mouse: NSEvent.mouseLocation, panelFrame: panel.frame)
        let targetScreenID = targetScreen?.displayUUID
        let guideSize = grid.cardSize(cSpan: sp.c, rSpan: sp.r, screen: targetScreen)
        let (targetCol, targetRow) = grid.gridSlot(forPanelFrame: panel.frame, screen: targetScreen, colSpan: sp.c, rowSpan: sp.r)
        let targetSlotOrigin = grid.cardOrigin(forCol: targetCol, row: targetRow, cardHeight: guideSize.height, screen: targetScreen)
        grid.showGuide(at: targetSlotOrigin, width: guideSize.width, height: guideSize.height)
        
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
                currentSlots: dragStartSlots,
                screen: targetScreen
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
        
        if didMove {
            let grid = GridSnapManager.shared
            let sp = grid.spans(of: note)
            let targetScreen = grid.targetScreen(mouse: NSEvent.mouseLocation, panelFrame: panel.frame)
            let targetScreenID = targetScreen?.displayUUID
            let (targetCol, targetRow) = grid.gridSlot(forPanelFrame: panel.frame, screen: targetScreen, colSpan: sp.c, rowSpan: sp.r)
            
            let targetNotes = grid.notes(store.notes, onScreen: targetScreenID).filter { $0.id != noteId }
            let finalSlots = grid.solveNonOverlappingSlots(
                movingNoteId: noteId,
                targetCol: targetCol,
                targetRow: targetRow,
                allNotes: [note] + targetNotes,
                currentSlots: dragStartSlots,
                screen: targetScreen
            )
            
            for idx in store.notes.indices {
                let id = store.notes[idx].id
                guard let slot = finalSlots[id] else { continue }
                store.notes[idx].gridCol = slot.col
                store.notes[idx].gridRow = slot.row
                if id == noteId { store.notes[idx].screenID = targetScreenID }
            }
            for id in finalSlots.keys { displaySlotOverrides.removeValue(forKey: id) }
            applyLayout(animated: true)
            SensoryFeedback.buttonClicked()
        }
    }
    
    /// Tries the screen under the mouse, then every other screen. Returns nil (and creates nothing) if no screen has a free slot.
    @discardableResult
    private func placeAndOpen(
        width: Double,
        height: Double,
        preferredCandidate: ((NSScreen?) -> (col: Int, row: Int)?)? = nil,
        make: (_ id: UUID, _ slot: (col: Int, row: Int), _ origin: CGPoint, _ screenID: String?) -> NoteCard
    ) -> UUID? {
        let grid = GridSnapManager.shared
        let sp = grid.legacySpans(width: width, height: height)
        var screens: [NSScreen?] = []
        let mouse = grid.screenUnderMouse()
        if let mouse { screens.append(mouse) }
        for s in NSScreen.screens where s != mouse { screens.append(s) }
        if screens.isEmpty { screens.append(nil) }
        
        for screen in screens {
            let screenID = screen?.displayUUID
            let sameScreenNotes = grid.notes(store.notes, onScreen: screenID)
            guard var slot = grid.findFreeSlot(cSpan: sp.c, rSpan: sp.r, existingNotes: sameScreenNotes, screen: screen) else { continue }
            if let candidate = preferredCandidate?(screen),
               grid.isSlotFree(col: candidate.col, row: candidate.row, cSpan: sp.c, rSpan: sp.r, existingNotes: sameScreenNotes, screen: screen) {
                slot = candidate
            }
            let id = UUID()
            let size = grid.cardSize(cSpan: sp.c, rSpan: sp.r, screen: screen)
            let origin = grid.cardOrigin(forCol: slot.col, row: slot.row, cardHeight: size.height, screen: screen)
            var note = make(id, slot, origin, screenID)
            note.colSpan = sp.c
            note.rowSpan = sp.r
            note.width = Double(size.width)
            note.height = Double(size.height)
            store.notes.append(note)
            openWidgetWindow(for: id, at: origin)
            // Every card shrinks back to base spans first, then expands again around the new card.
            applyLayout(animated: true)
            return id
        }
        return nil
    }
    
    public static let noRoomMessage = "No room on the desktop — remove a card first."
    
    public func showNoRoomAlert() {
        let alert = NSAlert()
        alert.messageText = "No room on your displays"
        alert.informativeText = "Remove or move a card to make space, then try again."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @discardableResult
    public func spawnNewWidget(near origin: CGPoint? = nil, title: String = "New Group", items: [NoteItem] = []) -> UUID? {
        let targetWidth: Double = 281
        let targetHeight: Double = 364
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(
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
                    title: title,
                    headerImagePath: nextWallpaper,
                    items: items,
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
    
    /// Pass `pages` to start with a specific title and content instead of the sample note.
    @discardableResult
    public func spawnNewFreeformNoteWidget(near origin: CGPoint? = nil, title: String? = nil, pages: [NotePage]? = nil) -> UUID? {
        let cardWidth: Double = 586.0
        let targetHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(width: cardWidth, height: targetHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .notes,
                title: title ?? "Strategy",
                noteContent: pages?.first?.content ?? NoteStore.defaultDemoNoteContent,
                pages: pages ?? NoteStore.defaultDemoPages,
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
    
    @discardableResult
    public func spawnNewFinderWidget(near origin: CGPoint? = nil) -> UUID? {
        let cardWidth: Double = 586.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .finder,
                title: "Notsky AI",
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
    
    @discardableResult
    public func spawnNewFoldersWidget(near origin: CGPoint? = nil) -> UUID? {
        let cardWidth: Double = 281.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
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
    
    @discardableResult
    public func spawnNewNowPlayingWidget(near origin: CGPoint? = nil) -> UUID? {
        let cardWidth: Double = 281.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
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
    
    @discardableResult
    public func spawnNewLinearWidget(near origin: CGPoint? = nil) -> UUID? {
        let cardWidth: Double = 586.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
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
    
    @discardableResult
    public func spawnNewVoiceOpenWidget(near origin: CGPoint? = nil) -> UUID? {
        let cardWidth: Double = 281.0
        let cardHeight: Double = 364.0
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        
        return placeAndOpen(width: cardWidth, height: cardHeight) { id, slot, origin, screenID in
            NoteCard(
                id: id,
                cardType: .voiceOpen,
                title: "Voice",
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
    
    /// Voice Open's hot key and key monitor exist only while at least one Voice Open card exists.
    private func syncVoiceOpenService() {
        VoiceOpenService.shared.setActive(store.notes.contains { $0.cardType == .voiceOpen })
    }
    
    /// The shared Linear service runs only while at least one Linear card exists.
    private func syncLinearService() {
        LinearService.shared.setActive(store.notes.contains { $0.cardType == .linear })
    }
    
    public func refreshNowPlayingService() { syncNowPlayingService() }

    /// The shared music service runs only while at least one Now Playing card exists (or a voice music command asked for it).
    private func syncNowPlayingService() {
        NowPlayingService.shared.setActive(store.notes.contains { $0.cardType == .nowPlaying } || VoiceOpenService.shared.musicRequested)
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
        applyLayout(animated: true)
        syncNowPlayingService()
        syncLinearService()
        syncVoiceOpenService()
    }
    
    public func windowOrigin(for noteId: UUID) -> CGPoint? {
        guard let panel = windowControllers[noteId]?.window else { return nil }
        let panelOrigin = panel.frame.origin
        return CGPoint(x: panelOrigin.x + 30, y: panelOrigin.y + 30)
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
        syncVoiceOpenService()
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
            title: "Notsky AI",
            noteContent: "",
            headerImagePath: w3,
            items: [],
            chatMessages: [],
            gridCol: 2,
            gridRow: 0,
            width: 586,
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
        applyLayout(animated: false)
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
                store.notes[3].title = "Notsky AI"
            }
        }
        
        store.saveToDisk()
        SensoryFeedback.buttonClicked()
    }
    
    public func fillDemoData() {
        setDemoData(enabled: true)
    }
}
