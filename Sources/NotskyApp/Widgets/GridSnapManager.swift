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
    
    // MARK: - Multi-Cell Span Calculations
    public func colSpan(for cardWidth: Double) -> Int {
        // Round UP (small tolerance) so a card wider than one cell reserves the next cell too.
        max(1, Int(ceil((CGFloat(cardWidth) + widgetSpacing) / cellWidth - 0.05)))
    }
    
    public func rowSpan(for cardHeight: Double) -> Int {
        max(1, Int(ceil((CGFloat(cardHeight) + widgetSpacing) / cellHeight - 0.05)))
    }
    
    // MARK: - Discrete Grid Slot Coordinate (col, row) from Live Panel Frame
    public func gridSlot(forPanelFrame frame: NSRect, screen: NSScreen?) -> (col: Int, row: Int) {
        let visibleFrame = visibleFrame(of: screen)
        let minX = visibleFrame.minX + edgeMarginX
        let maxCardTop = visibleFrame.maxY - edgeMarginY
        
        let cardX = frame.origin.x + 30
        let cardTopY = frame.origin.y + frame.height - 30
        
        let relativeX = cardX - minX
        let col = max(0, Int(round(relativeX / cellWidth)))
        
        let relativeY = maxCardTop - cardTopY
        let row = max(0, Int(round(relativeY / cellHeight)))
        
        return (col, row)
    }
    
    // MARK: - Discrete Grid Slot Coordinate (col, row) from Screen Point
    public func gridSlot(for cursor: CGPoint, screen: NSScreen?, cardWidth: CGFloat = 281, cardHeight: CGFloat = 364) -> (col: Int, row: Int) {
        let visibleFrame = visibleFrame(of: screen)
        let minX = visibleFrame.minX + edgeMarginX
        let maxCardTop = visibleFrame.maxY - edgeMarginY
        
        let relativeX = cursor.x - minX - (cardWidth / 2)
        let col = max(0, Int(round(relativeX / cellWidth)))
        
        let relativeY = maxCardTop - cursor.y - (cardHeight / 2)
        let row = max(0, Int(round(relativeY / cellHeight)))
        
        return (col, row)
    }
    
    // MARK: - Card Origin from (col, row)
    public func cardOrigin(forCol col: Int, row: Int, cardHeight: CGFloat, screen: NSScreen?) -> CGPoint {
        let visibleFrame = visibleFrame(of: screen)
        let minX = visibleFrame.minX + edgeMarginX
        let maxCardTop = visibleFrame.maxY - edgeMarginY
        
        let x = minX + (CGFloat(col) * cellWidth)
        let topY = maxCardTop - (CGFloat(row) * cellHeight)
        let y = topY - cardHeight
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Panel Origin from Card Origin (Accounting for 30pt glow shadow margin)
    public func panelOrigin(forCardOrigin cardOrigin: CGPoint, cardHeight: CGFloat, panelHeight: CGFloat) -> CGPoint {
        let cardTopY = cardOrigin.y + cardHeight
        let panelTopY = cardTopY + 30
        let panelY = panelTopY - panelHeight
        let panelX = cardOrigin.x - 30
        return CGPoint(x: panelX, y: panelY)
    }
    
    // MARK: - Find Next Open Slot (Zero Overlap for New Cards)
    public func findNextAvailableSlot(cardWidth targetWidth: Double, cardHeight targetHeight: Double, existingNotes: [NoteCard]) -> (col: Int, row: Int) {
        let cSpan = colSpan(for: targetWidth)
        let rSpan = rowSpan(for: targetHeight)
        
        let maxCols = 16
        let maxRows = 16
        var occupied = [[Bool]](repeating: [Bool](repeating: false, count: maxRows), count: maxCols)
        
        for note in existingNotes {
            let noteCSpan = colSpan(for: note.width)
            let noteRSpan = rowSpan(for: note.height)
            let colStart = max(0, note.gridCol)
            let rowStart = max(0, note.gridRow)
            let colEnd = min(maxCols, note.gridCol + noteCSpan)
            let rowEnd = min(maxRows, note.gridRow + noteRSpan)
            guard colStart < colEnd, rowStart < rowEnd else { continue }
            for c in colStart..<colEnd {
                for r in rowStart..<rowEnd {
                    occupied[c][r] = true
                }
            }
        }
        
        for r in 0..<maxRows {
            for c in 0..<maxCols {
                var canFit = true
                if c + cSpan > maxCols || r + rSpan > maxRows {
                    canFit = false
                } else {
                    for testC in c..<(c + cSpan) {
                        for testR in r..<(r + rSpan) {
                            if occupied[testC][testR] {
                                canFit = false
                                break
                            }
                        }
                        if !canFit { break }
                    }
                }
                if canFit {
                    return (c, r)
                }
            }
        }
        return (0, 0)
    }
    
    /// True if a card of the given size fits at (col,row) without touching any of `existingNotes`.
    public func isSlotFree(col: Int, row: Int, cardWidth: Double, cardHeight: Double, existingNotes: [NoteCard]) -> Bool {
        let cSpan = colSpan(for: cardWidth)
        let rSpan = rowSpan(for: cardHeight)
        for n in existingNotes {
            let nCSpan = colSpan(for: n.width)
            let nRSpan = rowSpan(for: n.height)
            if !(col + cSpan <= n.gridCol || col >= n.gridCol + nCSpan ||
                 row + rSpan <= n.gridRow || row >= n.gridRow + nRSpan) {
                return false
            }
        }
        return true
    }
    
    // MARK: - 2D Constraint-Based Layout Solver (Zero Overlap Guarantee)
    public func solveNonOverlappingSlots(
        movingNoteId: UUID,
        targetCol: Int,
        targetRow: Int,
        allNotes: [NoteCard],
        currentSlots: [UUID: (col: Int, row: Int)]
    ) -> [UUID: (col: Int, row: Int)] {
        guard let movingNote = allNotes.first(where: { $0.id == movingNoteId }),
              let movingOrig = currentSlots[movingNoteId] else { return currentSlots }
        
        let movingColSpan = colSpan(for: movingNote.width)
        let movingRowSpan = rowSpan(for: movingNote.height)
        
        let maxCols = 16
        let maxRows = 16
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
        let targetCol = max(0, min(targetCol, maxCols - movingColSpan))
        let targetRow = max(0, min(targetRow, maxRows - movingRowSpan))
        markPlaced(id: movingNoteId, col: targetCol, row: targetRow, cSpan: movingColSpan, rSpan: movingRowSpan)
        resultSlots[movingNoteId] = (targetCol, targetRow)
        
        // 2. Keep untouched notes in their original slots if no collision
        let otherNotes = allNotes.filter { $0.id != movingNoteId }
        var unplacedNotes: [NoteCard] = []
        
        for note in otherNotes {
            guard let slot = currentSlots[note.id] else { continue }
            let cSpan = colSpan(for: note.width)
            let rSpan = rowSpan(for: note.height)
            
            if canPlace(col: slot.col, row: slot.row, cSpan: cSpan, rSpan: rSpan) {
                markPlaced(id: note.id, col: slot.col, row: slot.row, cSpan: cSpan, rSpan: rSpan)
                resultSlots[note.id] = slot
            } else {
                unplacedNotes.append(note)
            }
        }
        
        // 3. Sort unplaced notes so larger widgets fill matching pockets first
        unplacedNotes.sort {
            let area0 = colSpan(for: $0.width) * rowSpan(for: $0.height)
            let area1 = colSpan(for: $1.width) * rowSpan(for: $1.height)
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
            let cSpan = colSpan(for: note.width)
            let rSpan = rowSpan(for: note.height)
            
            for cand in candidateSlots {
                if canPlace(col: cand.col, row: cand.row, cSpan: cSpan, rSpan: rSpan) {
                    markPlaced(id: note.id, col: cand.col, row: cand.row, cSpan: cSpan, rSpan: rSpan)
                    resultSlots[note.id] = (cand.col, cand.row)
                    break
                }
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
