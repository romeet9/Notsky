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

    /// True for the first assistant message after a user turn (shows the AI mark).
    var showAvatar: Bool = true

    private var bubbleMaxWidth: CGFloat { max(120, (cardWidth - 32) * 0.78) }

    private var renderedText: Text {
        if msg.role != "user",
           let attributed = try? AttributedString(
               markdown: msg.content,
               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
           ) {
            return Text(attributed)
        }
        return Text(msg.content)
    }

    var body: some View {
        if msg.role == "user" {
            HStack(alignment: .bottom, spacing: 4) {
                Spacer(minLength: 0)
                if msg.spoken == true {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isDark ? .white.opacity(0.5) : .black.opacity(0.4))
                        .padding(.bottom, 8)
                        .accessibilityLabel(Text("Spoken"))
                }
                renderedText
                    .scaledFont(size: 15, weight: .regular)
                    .foregroundStyle(isDark ? .white : .black)
                    .textSelection(.enabled)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        Color.accentColor.opacity(isDark ? 0.38 : 0.22),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.75)
                    )
                    .frame(maxWidth: bubbleMaxWidth, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .id(msg.id)
        } else {
            HStack(alignment: .top, spacing: 6) {
                Group {
                    if showAvatar {
                        RemixImage(.aiMark, scaledSize: 14)
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 18, height: 18)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    if !msg.content.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            if msg.isError == true {
                                RemixImage(.alertFill, scaledSize: 14)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 3)
                                    .accessibilityHidden(true)
                            }
                            renderedText
                                .scaledFont(size: 15, weight: .regular)
                                .foregroundStyle(isDark ? .white.opacity(0.92) : .black.opacity(0.85))
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                        )
                    }

                    if let actions = msg.actions, !actions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
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
                            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(msg.attachedFiles) { file in
                                FinderFileTile(file: file, isDark: isDark, sheetBackgroundColor: sheetBackgroundColor, specularBorderGradient: specularBorderGradient)
                            }
                        }
                    }
                }
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(msg.id)
        }
    }

    // MARK: - Action chip
    
    private func actionChip(_ action: ChatAction) -> some View {
        let wasUndone = agent.undone.contains(action.id)
        let canUndo = agent.canUndo(action.id)
        return HStack(spacing: 6) {
            RemixImage(wasUndone ? .arrowGoBackFill : .checkboxCircleFill, scaledSize: 14)
                .foregroundStyle(wasUndone ? Color.gray : Color.green)
                .accessibilityHidden(true)
            Text(wasUndone ? String(localized: "Undone: \(action.label)") : action.label)
                .scaledFont(size: 12, weight: .medium)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(isDark ? Color(white: 0.2).opacity(0.7) : Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
