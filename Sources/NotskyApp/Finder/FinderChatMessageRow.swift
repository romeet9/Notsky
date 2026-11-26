import SwiftUI
import AppKit

/// One user or assistant message (with action chips, confirmations and file tiles) in the Notsky AI card chat.
struct FinderChatMessageRow: View {
    let msg: ChatMessage
    let cardWidth: CGFloat
    let isDark: Bool
    let sheetBackgroundColor: Color
    let specularBorderGradient: LinearGradient
    /// (confirmation id, approved)
    var onResolve: (UUID, Bool) -> Void = { _, _ in }

    private var agent: NotskyAgent { NotskyAgent.shared }

    var body: some View {
        if msg.role == "user" {
            HStack {
                Spacer(minLength: 40)
                Text(msg.content)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(isDark ? .white : .black)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isDark ? Color(white: 0.22).opacity(0.85) : Color(white: 0.88).opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.08 : 0.04), radius: 4, y: 1.5)
            }
            .id(msg.id)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if !msg.content.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        if msg.isError == true {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .scaledFont(size: 12, weight: .semibold)
                                .foregroundStyle(.orange)
                                .padding(.top, 3)
                                .accessibilityHidden(true)
                        }
                        Text(msg.content)
                            .scaledFont(size: 15, weight: .regular)
                            .lineSpacing(3)
                            .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
                
                if let actions = msg.actions, !actions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(actions) { action in
                            actionChip(action)
                        }
                    }
                }
                
                if let confirmations = msg.confirmations, !confirmations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(confirmations) { confirmation in
                            confirmationRow(confirmation)
                        }
                    }
                }
                
                if !msg.attachedFiles.isEmpty {
                    LazyVGrid(
                        columns: cardWidth >= 500 ? [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ] : [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(msg.attachedFiles) { file in
                            FinderFileTile(file: file, isDark: isDark, sheetBackgroundColor: sheetBackgroundColor, specularBorderGradient: specularBorderGradient)
                        }
                    }
                }
            }
            .id(msg.id)
        }
    }
    
    // MARK: - Action chip
    
    private func actionChip(_ action: ChatAction) -> some View {
        let wasUndone = agent.undone.contains(action.id)
        let canUndo = agent.canUndo(action.id)
        return HStack(spacing: 6) {
            Image(systemName: wasUndone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(wasUndone ? Color.gray : Color.green)
                .accessibilityHidden(true)
            Text(wasUndone ? String(localized: "Undone: \(action.label)") : action.label)
                .scaledFont(size: 12.5, weight: .medium)
                .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                .strikethrough(wasUndone)
                .lineLimit(2)
            if canUndo {
                Button {
                    agent.undo(action.id)
                } label: {
                    Text("Undo")
                        .scaledFont(size: 12.5, weight: .semibold)
                        .underline()
                        .foregroundStyle(isDark ? .white : .black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Undo \(action.label)"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(specularBorderGradient, lineWidth: 0.75)
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Confirmation row
    
    private func confirmationRow(_ confirmation: ChatConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(confirmation.prompt)
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(isDark ? .white : .black)
                .fixedSize(horizontal: false, vertical: true)
            
            switch confirmation.status {
            case .pending:
                HStack(spacing: 8) {
                    Button {
                        SensoryFeedback.buttonClicked()
                        onResolve(confirmation.id, true)
                    } label: {
                        Text(confirmation.confirmLabel)
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(Color.red.opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(confirmation.confirmLabel))
                    
                    Button {
                        onResolve(confirmation.id, false)
                    } label: {
                        Text("Cancel")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(isDark ? .white : .black)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(sheetBackgroundColor, in: Capsule())
                            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                }
            case .confirmed:
                Text("Confirmed")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.5))
            case .cancelled:
                Text("Cancelled")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.5))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(specularBorderGradient, lineWidth: 0.75)
        )
    }
}

/// Three pulsing dots while Notsky AI is working. Static under Reduce Motion.
struct FinderTypingIndicator: View {
    let isDark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(isDark ? Color.white : Color.black)
                    .frame(width: 7, height: 7)
                    .opacity(reduceMotion ? 0.5 : (phase == index ? 0.85 : 0.25))
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement()
        .accessibilityLabel(Text("Notsky AI is thinking"))
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.easeInOut(duration: 0.2)) { phase = (phase + 1) % 3 }
            }
        }
    }
}
