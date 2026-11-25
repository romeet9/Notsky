import SwiftUI
import AppKit

/// Scrollable numbered task list of a task card.
struct NoteTaskList: View {
    @Binding var note: NoteCard
    let taskTextColor: Color
    let completedTaskColor: Color
    let accentColor: Color
    let isDark: Bool
    let fontSize: CGFloat
    let rowSpacing: CGFloat
    let contentWidth: CGFloat
    let cardWidth: CGFloat
    let showControls: Bool
    let isAddingTask: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: rowSpacing) {
                if note.items.isEmpty && !isAddingTask {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No tasks yet")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundStyle(taskTextColor.opacity(0.65))
                        Text("Click + to add your first task")
                            .scaledFont(size: 12.5, weight: .regular)
                            .foregroundStyle(taskTextColor.opacity(0.40))
                    }
                    .padding(.top, 16)
                    .padding(.leading, 2)
                } else {
                    ForEach($note.items) { $item in
                        let itemIndex = (note.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
                        TaskItemRow(
                            index: itemIndex,
                            item: $item,
                            taskTextColor: taskTextColor,
                            completedTaskColor: completedTaskColor,
                            accentColor: accentColor,
                            isDark: isDark,
                            fontSize: fontSize,
                            onDelete: {
                                note.items.removeAll { $0.id == item.id }
                            }
                        )
                    }
                }
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.top, (showControls || isAddingTask) ? 6 : 22)
            .padding(.bottom, (showControls || isAddingTask) ? 8 : 22)
        }
        .scrollIndicators(.hidden)
        .frame(width: cardWidth)
        .frame(maxHeight: .infinity)
        .contentEdgeFade(top: 12, bottom: 16)
    }
}
