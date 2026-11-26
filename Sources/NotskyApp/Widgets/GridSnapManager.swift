import SwiftUI
import AppKit

@MainActor
public final class GridSnapManager {
    public static let shared = GridSnapManager()
    
    public var guidePanel: NSPanel?
    public let cardWidth: CGFloat = 281
    public let cardHeight: CGFloat = 364
    
    // Exact macOS desktop widget margins (32pt from screen edges and menu bar)
    public let edgeMarginX: CGFloat = 32
    public let edgeMarginY: CGFloat = 32
    public let widgetSpacing: CGFloat = 24
    
    public var cellWidth: CGFloat { cardWidth + widgetSpacing }
    public var cellHeight: CGFloat { cardHeight + widgetSpacing }
    
    private var currentGuideWidth: CGFloat = 281
    private var currentGuideHeight: CGFloat = 364
    
    private init() {
        setupGuidePanel()
    }
    
    private func setupGuidePanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 341, height: 424),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .init(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: GridGuideView(width: 281, height: 364))
        
        self.guidePanel = panel
    }
    
    // MARK: - Screen Resolution

    /// Primary display (the one with the menu bar).
    public var primaryScreen: NSScreen? { NSScreen.screens.first ?? NSScreen.main }

    /// Screen for a saved display UUID; falls back to the primary screen if missing/disconnected.
    public func screen(for id: String?) -> NSScreen? {
        if let id = id, let match = NSScreen.screens.first(where: { $0.displayUUID == id }) {
            return match
        }
        return primaryScreen
    }

    /// Display UUID a saved screenID actually resolves to right now (nil screenID == primary).
    public func resolvedScreenID(_ id: String?) -> String? {
        screen(for: id)?.displayUUID
    }

    /// Screen currently containing the mouse pointer (falls back to primary).
    public func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? primaryScreen
    }

    /// Drag target: screen under the mouse, else the screen overlapping the panel frame most.
    public func targetScreen(mouse: CGPoint, panelFrame: NSRect) -> NSScreen? {
        if let hit = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return hit
        }
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let inter = screen.frame.intersection(panelFrame)
            let area = inter.isNull ? 0 : inter.width * inter.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? primaryScreen
    }

    /// Notes that physically live on the same display as `id` (nil == primary).
    public func notes(_ notes: [NoteCard], onScreen id: String?) -> [NoteCard] {
        let target = resolvedScreenID(id)
        return notes.filter { resolvedScreenID($0.screenID) == target }
    }

    private func visibleFrame(of screen: NSScreen?) -> NSRect {
        (screen ?? primaryScreen)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
    
    // MARK: - Per-Screen Responsive Metrics
    public struct GridMetrics {
        public var cols: Int
        public var rows: Int
        public var cellW: CGFloat
        public var cellH: CGFloat
        public var minX: CGFloat
        public var topY: CGFloat
    }
    
    private var metricsCache: [String: (frame: NSRect, metrics: GridMetrics)] = [:]
    
    public func invalidateMetrics() { metricsCache.removeAll() }
    
    /// Columns/rows that fit the display at the base card size, with cell size stretched so the grid
    /// spans the visibleFrame edge to edge (edge margins and gaps stay fixed).
    public func metrics(for screen: NSScreen?) -> GridMetrics {
        let s = screen ?? primaryScreen
        let vf = visibleFrame(of: s)
        let key = s?.displayUUID ?? ""
        if let cached = metricsCache[key], cached.frame == vf { return cached.metrics }
        let cols = max(1, Int(floor((vf.width - 2 * edgeMarginX + widgetSpacing) / cellWidth)))
        let rows = max(1, Int(floor((vf.height - 2 * edgeMarginY + widgetSpacing) / cellHeight)))
        let cellW = (vf.width - 2 * edgeMarginX - CGFloat(cols - 1) * widgetSpacing) / CGFloat(cols)
        let cellH = (vf.height - 2 * edgeMarginY - CGFloat(rows - 1) * widgetSpacing) / CGFloat(rows)
        let m = GridMetrics(cols: cols, rows: rows, cellW: cellW, cellH: cellH,
                            minX: vf.minX + edgeMarginX, topY: vf.maxY - edgeMarginY)
        metricsCache[key] = (vf, m)
        return m
    }
    
    public func maxCols(for screen: NSScreen?) -> Int { metrics(for: screen).cols }
    public func maxRows(for screen: NSScreen?) -> Int { metrics(for: screen).rows }
    
    /// Stretched pixel size of a card spanning (cSpan x rSpan) cells on this screen.
    public func cardSize(cSpan: Int, rSpan: Int, screen: NSScreen?) -> CGSize {
        let m = metrics(for: screen)
        return CGSize(width: CGFloat(cSpan) * m.cellW + CGFloat(cSpan - 1) * widgetSpacing,
                      height: CGFloat(rSpan) * m.cellH + CGFloat(rSpan - 1) * widgetSpacing)
    }
    
    /// Unstretched base size (used by the drawer shelf).
    public func baseCardSize(cSpan: Int, rSpan: Int) -> CGSize {
        CGSize(width: CGFloat(cSpan) * cardWidth + CGFloat(cSpan - 1) * widgetSpacing,
               height: CGFloat(rSpan) * cardHeight + CGFloat(rSpan - 1) * widgetSpacing)
    }
    
    /// Base (persisted) spans of a card.
    public func spans(of note: NoteCard) -> (c: Int, r: Int) {
        let d = NoteCard.defaultSpans(for: note.cardType)
        return (max(1, note.colSpan ?? d.c), max(1, note.rowSpan ?? d.r))
    }
    
    /// Spans a card of a given pixel width/height would take at the base 281x364 cell.
    public func legacySpans(width: Double, height: Double) -> (c: Int, r: Int) {
        (max(1, Int(ceil((CGFloat(width) + widgetSpacing) / cellWidth - 0.05))),
         max(1, Int(ceil((CGFloat(height) + widgetSpacing) / cellHeight - 0.05))))
    }
    
    /// Spans for a pixel size on a screen's stretched grid (used by edge-drag resizing).
    public func spans(forPixelWidth w: Double, height h: Double, screen: NSScreen?) -> (c: Int, r: Int) {
        let m = metrics(for: screen)
        let c = Int(round((CGFloat(w) + widgetSpacing) / (m.cellW + widgetSpacing)))
        let r = Int(round((CGFloat(h) + widgetSpacing) / (m.cellH + widgetSpacing)))
        return (max(1, min(c, m.cols)), max(1, min(r, m.rows)))
    }
    
    /// True if a card with these spans placed at (col,row) stays inside the screen's grid.
    public func fits(col: Int, row: Int, cSpan: Int, rSpan: Int, screen: NSScreen?) -> Bool {
        col >= 0 && row >= 0 && col + cSpan <= maxCols(for: screen) && row + rSpan <= maxRows(for: screen)
    }
    
    /// Last slot (bottom-right) where a card with these spans still fits the screen.
    public func lastFittingSlot(cSpan: Int, rSpan: Int, screen: NSScreen?) -> (col: Int, row: Int) {
        (max(0, maxCols(for: screen) - cSpan), max(0, maxRows(for: screen) - rSpan))
    }
    
    // MARK: - Discrete Grid Slot Coordinate (col, row) from Live Panel Frame
    public func gridSlot(forPanelFrame frame: NSRect, screen: NSScreen?, colSpan cSpan: Int = 1, rowSpan rSpan: Int = 1) -> (col: Int, row: Int) {
        let m = metrics(for: screen)
        let cardX = frame.origin.x + 30
        let cardTopY = frame.origin.y + frame.height - 30
        let col = max(0, min(Int(round((cardX - m.minX) / (m.cellW + widgetSpacing))), m.cols - cSpan))
        let row = max(0, min(Int(round((m.topY - cardTopY) / (m.cellH + widgetSpacing))), m.rows - rSpan))
        return (col, row)
    }
    
    // MARK: - Discrete Grid Slot Coordinate (col, row) from Screen Point
    public func gridSlot(for cursor: CGPoint, screen: NSScreen?, cSpan: Int = 1, rSpan: Int = 1) -> (col: Int, row: Int) {
        let m = metrics(for: screen)
        let size = cardSize(cSpan: cSpan, rSpan: rSpan, screen: screen)
        let col = max(0, min(Int(round((cursor.x - m.minX - size.width / 2) / (m.cellW + widgetSpacing))), m.cols - cSpan))
        let row = max(0, min(Int(round((m.topY - cursor.y - size.height / 2) / (m.cellH + widgetSpacing))), m.rows - rSpan))
        return (col, row)
    }
    
    // MARK: - Card Origin from (col, row)
    public func cardOrigin(forCol col: Int, row: Int, cardHeight: CGFloat, screen: NSScreen?) -> CGPoint {
        let m = metrics(for: screen)
        let x = m.minX + CGFloat(col) * (m.cellW + widgetSpacing)
        let topY = m.topY - CGFloat(row) * (m.cellH + widgetSpacing)
        return CGPoint(x: x, y: topY - cardHeight)
    }
    
    // MARK: - Panel Origin from Card Origin (Accounting for 30pt glow shadow margin)
    public func panelOrigin(forCardOrigin cardOrigin: CGPoint, cardHeight: CGFloat, panelHeight: CGFloat) -> CGPoint {
        let cardTopY = cardOrigin.y + cardHeight
        let panelTopY = cardTopY + 30
        let panelY = panelTopY - panelHeight
        let panelX = cardOrigin.x - 30
        return CGPoint(x: panelX, y: panelY)
    }
    
    // MARK: - Occupancy
    private func occupancy(of notes: [NoteCard], screen: NSScreen?) -> [[Bool]] {
        let m = metrics(for: screen)
        var occupied = [[Bool]](repeating: [Bool](repeating: false, count: m.rows), count: m.cols)
        for note in notes {
            let s = spans(of: note)
            let c0 = max(0, note.gridCol), r0 = max(0, note.gridRow)
            let c1 = min(m.cols, note.gridCol + s.c), r1 = min(m.rows, note.gridRow + s.r)
            guard c0 < c1, r0 < r1 else { continue }
            for c in c0..<c1 { for r in r0..<r1 { occupied[c][r] = true } }
        }
        return occupied
    }
    
    // MARK: - Find Next Open Slot (Zero Overlap for New Cards)
    /// Last-resort variant: if the screen is full, returns the last fitting slot (may overlap).
    public func findNextAvailableSlot(cSpan: Int, rSpan: Int, existingNotes: [NoteCard], screen: NSScreen?) -> (col: Int, row: Int) {
        findFreeSlot(cSpan: cSpan, rSpan: rSpan, existingNotes: existingNotes, screen: screen)
            ?? lastFittingSlot(cSpan: cSpan, rSpan: rSpan, screen: screen)
    }
    
    /// First free slot (reading order) that fits the screen (using base spans), or nil if full.
    public func findFreeSlot(cSpan: Int, rSpan: Int, existingNotes: [NoteCard], screen: NSScreen?) -> (col: Int, row: Int)? {
        let m = metrics(for: screen)
        let occupied = occupancy(of: existingNotes, screen: screen)
        for r in 0..<m.rows {
            for c in 0..<m.cols {
                guard c + cSpan <= m.cols, r + rSpan <= m.rows else { continue }
                var canFit = true
                outer: for tc in c..<(c + cSpan) {
                    for tr in r..<(r + rSpan) where occupied[tc][tr] { canFit = false; break outer }
                }
                if canFit { return (c, r) }
            }
        }
        return nil
    }
    
    /// True if a card with these spans fits at (col,row) without touching any of `existingNotes`.
    public func isSlotFree(col: Int, row: Int, cSpan: Int, rSpan: Int, existingNotes: [NoteCard], screen: NSScreen?) -> Bool {
        guard fits(col: col, row: row, cSpan: cSpan, rSpan: rSpan, screen: screen) else { return false }
        for n in existingNotes {
            let s = spans(of: n)
            if !(col + cSpan <= n.gridCol || col >= n.gridCol + s.c ||
                 row + rSpan <= n.gridRow || row >= n.gridRow + s.r) {
                return false
            }
        }
        return true
    }
    
    // MARK: - Expansion (display-only)
    /// Grows each card (reading order) right then down into empty cells until nothing can grow.
    public func expandedSpans(for notes: [NoteCard], slots: [UUID: (col: Int, row: Int)], screen: NSScreen?) -> [UUID: (c: Int, r: Int)] {
        let m = metrics(for: screen)
        var occupied = [[Bool]](repeating: [Bool](repeating: false, count: m.rows), count: m.cols)
        var items: [(id: UUID, col: Int, row: Int, c: Int, r: Int)] = []
        for n in notes {
            let s = spans(of: n)
            let slot = slots[n.id] ?? (n.gridCol, n.gridRow)
            let col = max(0, min(slot.col, m.cols - 1)), row = max(0, min(slot.row, m.rows - 1))
            let c = min(s.c, m.cols - col), r = min(s.r, m.rows - row)
            for cc in col..<(col + c) { for rr in row..<(row + r) { occupied[cc][rr] = true } }
            items.append((n.id, col, row, c, r))
        }
        items.sort { $0.row != $1.row ? $0.row < $1.row : $0.col < $1.col }
        var changed = true
        while changed {
            changed = false
            for i in items.indices {
                var it = items[i]
                while it.col + it.c < m.cols,
                      (it.row..<(it.row + it.r)).allSatisfy({ !occupied[it.col + it.c][$0] }) {
                    for rr in it.row..<(it.row + it.r) { occupied[it.col + it.c][rr] = true }
                    it.c += 1
                    changed = true
                }
                while it.row + it.r < m.rows,
                      (it.col..<(it.col + it.c)).allSatisfy({ !occupied[$0][it.row + it.r] }) {
                    for cc in it.col..<(it.col + it.c) { occupied[cc][it.row + it.r] = true }
                    it.r += 1
                    changed = true
                }
                items[i] = it
            }
        }
        var result: [UUID: (c: Int, r: Int)] = [:]
        for it in items { result[it.id] = (it.c, it.r) }
        return result
    }
    
    // MARK: - 2D Constraint-Based Layout Solver (Zero Overlap Guarantee)
    public func solveNonOverlappingSlots(
        movingNoteId: UUID,
        targetCol: Int,
        targetRow: Int,
        allNotes: [NoteCard],
        currentSlots: [UUID: (col: Int, row: Int)],
        screen: NSScreen?
    ) -> [UUID: (col: Int, row: Int)] {
        guard let movingNote = allNotes.first(where: { $0.id == movingNoteId }),
              let movingOrig = currentSlots[movingNoteId] else { return currentSlots }
        
        let movingColSpan = spans(of: movingNote).c
        let movingRowSpan = spans(of: movingNote).r
        
        let maxCols = self.maxCols(for: screen)
        let maxRows = self.maxRows(for: screen)
        var occupied = [[UUID?]](repeating: [UUID?](repeating: nil, count: maxRows), count: maxCols)
        
        func canPlace(col: Int, row: Int, cSpan: Int, rSpan: Int) -> Bool {
            if col < 0 || row < 0 || col + cSpan > maxCols || row + rSpan > maxRows { return false }
            for c in col..<(col + cSpan) {
                for r in row..<(row + rSpan) {
                    if occupied[c][r] != nil { return false }
                }
            }
            return true
        }
        
        func markPlaced(id: UUID, col: Int, row: Int, cSpan: Int, rSpan: Int) {
            let c0 = max(0, col), r0 = max(0, row)
            let c1 = min(maxCols, col + cSpan), r1 = min(maxRows, row + rSpan)
            guard c0 < c1, r0 < r1 else { return }
            for c in c0..<c1 {
                for r in r0..<r1 {
                    occupied[c][r] = id
                }
            }
        }
        
        var resultSlots: [UUID: (col: Int, row: Int)] = [:]
        
        // 1. Lock the moving widget into its (clamped) target slot
        let targetCol = max(0, min(targetCol, max(0, maxCols - movingColSpan)))
        let targetRow = max(0, min(targetRow, max(0, maxRows - movingRowSpan)))
        markPlaced(id: movingNoteId, col: targetCol, row: targetRow, cSpan: movingColSpan, rSpan: movingRowSpan)
        resultSlots[movingNoteId] = (targetCol, targetRow)
        
        // 2. Keep untouched notes in their original slots if no collision
        let otherNotes = allNotes.filter { $0.id != movingNoteId }
        var unplacedNotes: [NoteCard] = []
        
        for note in otherNotes {
            guard let slot = currentSlots[note.id] else { continue }
            let cSpan = spans(of: note).c
            let rSpan = spans(of: note).r
            
            if canPlace(col: slot.col, row: slot.row, cSpan: cSpan, rSpan: rSpan) {
                markPlaced(id: note.id, col: slot.col, row: slot.row, cSpan: cSpan, rSpan: rSpan)
                resultSlots[note.id] = slot
            } else {
                unplacedNotes.append(note)
            }
        }
        
        // 3. Sort unplaced notes so larger widgets fill matching pockets first
        unplacedNotes.sort {
            let area0 = spans(of: $0).c * spans(of: $0).r
            let area1 = spans(of: $1).c * spans(of: $1).r
            if area0 != area1 { return area0 > area1 }
            let slot0 = currentSlots[$0.id] ?? (0, 0)
            let slot1 = currentSlots[$1.id] ?? (0, 0)
            if slot0.row != slot1.row { return slot0.row < slot1.row }
            return slot0.col < slot1.col
        }
        
        // Prioritized candidates: First check the vacated region of movingNote, then global scan
        var candidateSlots: [(col: Int, row: Int)] = []
        let vacRowLo = max(0, min(maxRows, movingOrig.row))
        let vacRowHi = max(vacRowLo, min(maxRows, movingOrig.row + movingRowSpan))
        let vacColLo = max(0, min(maxCols, movingOrig.col))
        let vacColHi = max(vacColLo, min(maxCols, movingOrig.col + movingColSpan))
        for r in vacRowLo ..< vacRowHi {
            for c in vacColLo ..< vacColHi {
                candidateSlots.append((c, r))
            }
        }
        for r in 0..<maxRows {
            for c in 0..<maxCols {
                if !candidateSlots.contains(where: { $0.col == c && $0.row == r }) {
                    candidateSlots.append((c, r))
                }
            }
        }
        
        for note in unplacedNotes {
            let cSpan = spans(of: note).c
            let rSpan = spans(of: note).r
            var placedIt = false
            
            for cand in candidateSlots {
                if canPlace(col: cand.col, row: cand.row, cSpan: cSpan, rSpan: rSpan) {
                    markPlaced(id: note.id, col: cand.col, row: cand.row, cSpan: cSpan, rSpan: rSpan)
                    resultSlots[note.id] = (cand.col, cand.row)
                    placedIt = true
                    break
                }
            }
            if !placedIt {
                // Screen full: last fitting slot (overlap allowed as last resort), never off-screen.
                let fallback = lastFittingSlot(cSpan: cSpan, rSpan: rSpan, screen: screen)
                resultSlots[note.id] = fallback
            }
        }
        
        return resultSlots
    }
    
    public func showGuide(at targetOrigin: CGPoint, width: CGFloat = 281, height: CGFloat = 364) {
        guard let guidePanel = guidePanel else { return }
        
        let panelWidth = width + 60
        let panelHeight = height + 60
        let panelOrigin = CGPoint(x: targetOrigin.x - 30, y: targetOrigin.y - 30)
        
        if currentGuideWidth != width || currentGuideHeight != height {
            currentGuideWidth = width
            currentGuideHeight = height
            guidePanel.setFrame(NSRect(origin: panelOrigin, size: CGSize(width: panelWidth, height: panelHeight)), display: true)
            guidePanel.contentView = NSHostingView(rootView: GridGuideView(width: width, height: height))
        } else {
            guidePanel.setFrameOrigin(panelOrigin)
        }
        
        if !guidePanel.isVisible {
            guidePanel.orderFrontRegardless()
        }
    }
    
    public func hideGuide() {
        guidePanel?.orderOut(nil)
    }
}
