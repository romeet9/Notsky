import SwiftUI
import AppKit

/// Edge and corner drag handles shared by every card view (tasks, freeform notes, folders, finder).
struct CardResizeHandles: View {
    @Binding var note: NoteCard
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let widthRange: ClosedRange<Double>
    let heightRange: ClosedRange<Double>

    @State private var dragInitialWidth: Double?
    @State private var dragInitialHeight: Double?

    var body: some View {
        rightEdge
        bottomEdge
        bottomRightCorner
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(range.upperBound, value))
    }

    private func setCursor(_ cursor: NSCursor, inside: Bool) {
        if inside { cursor.push() } else { NSCursor.pop() }
    }

    private func resize(toWidth width: Double?, height: Double?) {
        let newW = width ?? note.width
        let newH = height ?? note.height
        guard abs(note.width - newW) >= 0.5 || abs(note.height - newH) >= 0.5 else { return }
        note.width = newW
        note.height = newH
        WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: newH)
    }

    private func finishDrag() {
        dragInitialWidth = nil
        dragInitialHeight = nil
        SensoryFeedback.buttonClicked()
    }

    private var rightEdge: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: 20, height: max(20, cardHeight - 20))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialWidth == nil { dragInitialWidth = note.width }
                            let base = dragInitialWidth ?? note.width
                            resize(toWidth: clamp(base + Double(value.translation.width), to: widthRange), height: nil)
                        }
                        .onEnded { _ in finishDrag() }
                )
                .onHover { setCursor(.resizeLeftRight, inside: $0) }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topTrailing)
    }

    private var bottomEdge: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: max(20, cardWidth - 20), height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialHeight == nil { dragInitialHeight = note.height }
                            let base = dragInitialHeight ?? note.height
                            resize(toWidth: nil, height: clamp(base + Double(value.translation.height), to: heightRange))
                        }
                        .onEnded { _ in finishDrag() }
                )
                .onHover { setCursor(.resizeUpDown, inside: $0) }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomLeading)
    }

    private var bottomRightCorner: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if dragInitialWidth == nil { dragInitialWidth = note.width }
                                if dragInitialHeight == nil { dragInitialHeight = note.height }
                                let baseW = dragInitialWidth ?? note.width
                                let baseH = dragInitialHeight ?? note.height
                                resize(
                                    toWidth: clamp(baseW + Double(value.translation.width), to: widthRange),
                                    height: clamp(baseH + Double(value.translation.height), to: heightRange)
                                )
                            }
                            .onEnded { _ in finishDrag() }
                    )
                    .onHover { setCursor(.crosshair, inside: $0) }
            }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomTrailing)
    }
}
