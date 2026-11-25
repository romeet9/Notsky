import SwiftUI
import AppKit

/// Inline "Write your task" row shown while adding a task.
struct NoteTaskInputField: View {
    let nextIndex: Int
    let accentColor: Color
    let taskTextColor: Color
    let contentWidth: CGFloat
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(nextIndex).")
                .scaledFont(size: 15, weight: .semibold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(accentColor.opacity(0.85))
                .frame(minWidth: 18, alignment: .leading)
                .padding(.top, 1)

            TextField("Write your task", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .scaledFont(size: 15, weight: .regular, design: .default)
                .tracking(-0.4)
                .textFieldStyle(.plain)
                .foregroundStyle(taskTextColor)
                .focused(isFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit(onSubmit)
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.vertical, 4)
        .motionTransition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }
}
