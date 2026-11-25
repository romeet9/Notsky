import SwiftUI
import AppKit

// MARK: - Task Item Row (Numbered Tasks)

public struct TaskItemRow: View {
    public let index: Int
    @Binding public var item: NoteItem
    public let taskTextColor: Color
    public let completedTaskColor: Color
    public let accentColor: Color
    public let isDark: Bool
    public let fontSize: CGFloat
    public let onDelete: () -> Void
    
    @State private var isHoveringRow: Bool = false
    
    public init(
        index: Int,
        item: Binding<NoteItem>,
        taskTextColor: Color,
        completedTaskColor: Color,
        accentColor: Color,
        isDark: Bool,
        fontSize: CGFloat = 15.0,
        onDelete: @escaping () -> Void
    ) {
        self.index = index
        self._item = item
        self.taskTextColor = taskTextColor
        self.completedTaskColor = completedTaskColor
        self.accentColor = accentColor
        self.isDark = isDark
        self.fontSize = fontSize
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Number indicator: "1.", "2.", "3."
            Text("\(index).")
                .scaledFont(size: fontSize, weight: .semibold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(
                    item.isCompleted 
                        ? completedTaskColor.opacity(isDark ? 0.75 : 0.65)
                        : (isHoveringRow ? accentColor : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40)))
                )
                .frame(minWidth: 18, alignment: .leading)
                .padding(.top, 1)
            
            Text(item.text)
                .scaledFont(size: fontSize, weight: .regular, design: .default)
                .tracking(-0.4)
                .lineSpacing(2.5)
                .foregroundStyle(item.isCompleted ? completedTaskColor : taskTextColor)
                .strikethrough(item.isCompleted, color: completedTaskColor.opacity(isDark ? 0.75 : 0.65))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onHover { isHoveringRow = $0 }
        .onTapGesture {
            withMotion(.spring(response: 0.28, dampingFraction: 0.82)) {
                item.isCompleted.toggle()
            }
            if item.isCompleted {
                SensoryFeedback.taskCompleted()
            } else {
                SensoryFeedback.taskUnchecked()
            }
        }
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Delete Task") {
                withMotion {
                    onDelete()
                }
                SensoryFeedback.taskDeleted()
            }
        }
    }
}
