import SwiftUI
import AppKit

@MainActor
public struct FinderCardView: View {
    @Binding public var note: NoteCard
    @Environment(\.colorScheme) private var colorScheme
    
    public var onSpawnWidget: () -> Void = {}
    public var onDelete: () -> Void = {}
    
    private var settings: AppSettings { AppSettings.shared }
    
    @State private var inputText: String = ""
    @State private var isWorking: Bool = false
    @State private var isHoveringPlus: Bool = false
    @State private var isHoveringTools: Bool = false
    @State private var isHoveringOpenFinder: Bool = false
    
    private var account: GroqAccount { GroqAccount.shared }
    private var isConnected: Bool { account.hasKey }
    private let maxStoredMessages = 50
    
    // Quick suggestion prompts
    private var quickSuggestions: [String] {
        var list = [
            String(localized: "What's on my desktop?"),
            String(localized: "Add a task to buy milk"),
            String(localized: "Pin my notes card")
        ]
        if account.searchFilesEnabled { list.insert(String(localized: "Find my resume PDF"), at: 0) }
        return list
    }
    
    // MARK: - Layout Constants Matching Notsky Spec
    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    
    private let minCardWidth: Double = 281
    private let maxCardWidth: Double = 586
    private let minCardHeight: Double = 260
    private let maxCardHeight: Double = 752
    
    private var isDark: Bool {
        if let override = settings.preferredColorScheme {
            return override == .dark
        }
        return colorScheme == .dark
    }
    
    private var sheetBackgroundColor: Color {
        let opacity = settings.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }
    
    private func buttonBackgroundColor(hovering: Bool) -> Color {
        if isDark {
            return hovering ? Color(white: 0.16).opacity(0.90) : sheetBackgroundColor
        } else {
            return hovering ? Color.white.opacity(0.98) : sheetBackgroundColor
        }
    }
    
    private var specularBorderGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(isDark ? 0.35 : 0.70), location: 0.0),
                .init(color: Color.white.opacity(isDark ? 0.12 : 0.25), location: 0.5),
                .init(color: Color.white.opacity(isDark ? 0.02 : 0.08), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    public init(
        note: Binding<NoteCard>,
        onSpawnWidget: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self._note = note
        self.onSpawnWidget = onSpawnWidget
        self.onDelete = onDelete
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // 1. Full-Card Background Image
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // 2. Foreground Content Sheet
            ZStack(alignment: .top) {
                // Frosted Glass Tint & Hardware Accelerated Material
                sheetBackgroundColor
                    .background(.ultraThinMaterial)
                
                // Main Sheet Content
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        topToolbar
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                        
                        chatScrollView
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                    }
                    
                    // Pure Bottom Floating Bar
                    bottomFloatingBar
                }
            }
            .frame(width: cardWidth, height: sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .offset(y: headerHeight)
            .zIndex(1)
            
            // 3. Top Header Space (Exact 53pt Height with Centered Dual Glass Capsules)
            headerTitleCapsules
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)
            
            // 4. Smooth Edge Resize Handles
            CardResizeHandles(
                note: $note,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                widthRange: minCardWidth...maxCardWidth,
                heightRange: minCardHeight...maxCardHeight
            )
                .zIndex(20)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    // MARK: - Header Capsules
    private var headerTitleCapsules: some View {
        HStack(spacing: 8) {
            // Notsky AI title capsule
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(.red)
                
                Text("AI")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(isDark ? .white : .black)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: false), in: Capsule())
            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
            
            // Status Capsule (Live AI Ping/Ready Indicator)
            HStack(spacing: 5) {
                Circle()
                    .fill(isWorking ? Color.orange : (isConnected ? Color.green : Color.gray))
                    .frame(width: 7, height: 7)
                
                Text(isWorking ? LocalizedStringKey("thinking") : (isConnected ? LocalizedStringKey("ready") : LocalizedStringKey("not connected")))
                    .scaledFont(size: 12, weight: .medium, design: .rounded)
                    .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: false), in: Capsule())
            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            // Plus / New Chat Button (36 × 36 pt)
            Button(action: {
                SensoryFeedback.buttonClicked()
                withMotion(.spring(response: 0.25, dampingFraction: 0.8)) {
                    note.chatMessages.removeAll()
                    isWorking = false
                }
            }) {
                Image(systemName: "square.and.pencil")
                    .accessibilityLabel("Clear chat")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringPlus), in: Circle())
                    .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPlus = $0 }
            .help("Clear chat")
            
            Spacer()
            
            // 4-Icon Action Cluster Pill
            HStack(spacing: 11) {
                // 1. Groq key & model settings
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    SettingsWindowManager.shared.showSettings(item: .ai)
                }) {
                    Image(systemName: "key.fill")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(isConnected ? Color.green : (isDark ? .white.opacity(0.5) : .black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .help("AI Settings")
                .accessibilityLabel("AI Settings")
                
                // 2. Pin Button (Pin on Top / Floating)
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    withMotion(.spring(response: 0.25, dampingFraction: 0.8)) {
                        note.isPinned.toggle()
                        WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                    }
                }) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(note.isPinned ? Color.orange : (isDark ? .white.opacity(0.85) : .black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .help(note.isPinned ? LocalizedStringKey("Unpin (Desktop Canvas)") : LocalizedStringKey("Pin on Top (Floating)"))
                
                // 3. Cycle Wallpaper Button
                Button(action: {
                    cycleWallpaper()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Next Wallpaper in Pack")
                .accessibilityLabel("Next Wallpaper in Pack")
                
                // 4. Custom Header Image / Wallpaper Picker
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    selectCustomHeaderImage()
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Change Header Image")
                .accessibilityLabel("Change Header Image")
                
                // 5. Trash / Delete Button
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Delete Widget")
                .accessibilityLabel("Delete Widget")
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: isHoveringTools), in: Capsule())
            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            .onHover { isHoveringTools = $0 }
        }
    }
    
    // MARK: - Chat Scroll View
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    if !isConnected && note.chatMessages.isEmpty {
                        FinderNotConnectedState(isDark: isDark, specularBorderGradient: specularBorderGradient)
                    } else if note.chatMessages.isEmpty {
                        FinderEmptyState(
                            isDark: isDark,
                            specularBorderGradient: specularBorderGradient,
                            suggestions: quickSuggestions,
                            onSelect: { suggestion in
                                inputText = suggestion
                                sendMessage()
                            }
                        )
                    } else {
                        ForEach(note.chatMessages) { message in
                            FinderChatMessageRow(
                                msg: message,
                                cardWidth: cardWidth,
                                isDark: isDark,
                                sheetBackgroundColor: sheetBackgroundColor,
                                specularBorderGradient: specularBorderGradient,
                                onResolve: { confirmationID, approve in
                                    resolveConfirmation(messageID: message.id, confirmationID: confirmationID, approve: approve)
                                }
                            )
                        }
                    }
                    
                    if isWorking {
                        FinderTypingIndicator(isDark: isDark)
                            .padding(.vertical, 4)
                            .id("typing_indicator")
                    }
                    
                    Color.clear.frame(height: 1).id("chat_bottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.bottom, 95)
            }
            .scrollIndicators(.hidden)
            .contentEdgeFade(top: 22, bottom: 44)
            .onChange(of: note.chatMessages.count) {
                withMotion { proxy.scrollTo("chat_bottom", anchor: .bottom) }
            }
            .onChange(of: isWorking) {
                withMotion { proxy.scrollTo("chat_bottom", anchor: .bottom) }
            }
        }
    }
    
    // MARK: - Bottom Floating Bar with Input Bar & Open Finder Button
    private var bottomFloatingBar: some View {
        HStack(spacing: 6) {
            // macOS Spotlight Style Input Bar
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                    .padding(.top, 9)
                
                TextField("Ask Notsky AI...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .scaledFont(size: 15, weight: .regular)
                    .padding(.vertical, 7)
                    .disabled(!isConnected)
                    .accessibilityLabel("Message Notsky AI")
                    .onSubmit { sendMessage() }
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            inputText += "\n"
                            return .handled
                        }
                        sendMessage()
                        return .handled
                    }
                
                if !inputText.isEmpty {
                    Button(action: { sendMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .accessibilityLabel("Send")
                            .scaledFont(size: 18)
                            .foregroundStyle(isDark ? .white : .black)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 7)
                    .disabled(isWorking)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(
                isDark ? Color(white: 0.16).opacity(0.88) : Color.white.opacity(0.88),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 6, x: 0, y: 1.5)
            
            // "Open Finder" CTA Button (Height 36pt)
            Button(action: {
                SensoryFeedback.buttonClicked()
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
            }) {
                if cardWidth < 340 {
                    Image(systemName: "folder.fill")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(isDark ? .white.opacity(0.95) : .black.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(
                            isDark ? Color(white: 0.18).opacity(isHoveringOpenFinder ? 0.95 : 0.88) : Color.white.opacity(isHoveringOpenFinder ? 0.95 : 0.88),
                            in: Circle()
                        )
                        .background(.thinMaterial, in: Circle())
                        .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                        .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 6, x: 0, y: 1.5)
                } else {
                    Text("Open Finder")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(isDark ? .white.opacity(0.95) : .black.opacity(0.9))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            isDark ? Color(white: 0.18).opacity(isHoveringOpenFinder ? 0.95 : 0.88) : Color.white.opacity(isHoveringOpenFinder ? 0.95 : 0.88),
                            in: Capsule()
                        )
                        .background(.thinMaterial, in: Capsule())
                        .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                        .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 6, x: 0, y: 1.5)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHoveringOpenFinder = $0 }
            .help("Open macOS Finder")
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(
            ZStack {
                VisualEffectBlur(material: isDark ? .hudWindow : .underWindowBackground, blendingMode: .withinWindow)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.0), location: 0.0),
                                .init(color: Color.black.opacity(0.40), location: 0.28),
                                .init(color: Color.black.opacity(0.85), location: 0.60),
                                .init(color: Color.black.opacity(1.0), location: 0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                LinearGradient(
                    stops: [
                        .init(color: sheetBackgroundColor.opacity(0.0), location: 0.0),
                        .init(color: sheetBackgroundColor.opacity(isDark ? 0.35 : 0.40), location: 0.25),
                        .init(color: sheetBackgroundColor.opacity(isDark ? 0.75 : 0.75), location: 0.55),
                        .init(color: sheetBackgroundColor.opacity(isDark ? 0.95 : 0.95), location: 0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Message Execution
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isConnected, !isWorking else { return }
        
        SensoryFeedback.buttonClicked()
        inputText = ""
        
        let history = note.chatMessages
        note.chatMessages.append(ChatMessage(role: "user", content: trimmed))
        note.chatMessages.capChatHistory(maxStoredMessages)
        isWorking = true
        
        Task {
            let outcome = await NotskyAgent.shared.run(trimmed, history: history, style: .chat)
            let reply = ChatMessage(
                role: "assistant",
                content: outcome.reply,
                attachedFiles: outcome.files,
                actions: outcome.actions.isEmpty ? nil : outcome.actions,
                confirmations: outcome.confirmations.isEmpty ? nil : outcome.confirmations,
                isError: outcome.error != nil && outcome.actions.isEmpty ? true : nil
            )
            note.chatMessages.append(reply)
            note.chatMessages.capChatHistory(maxStoredMessages)
            isWorking = false
            SensoryFeedback.timerFinished()
        }
    }
    
    /// Runs or cancels a destructive step the assistant asked about. Nothing executes until the user taps.
    private func resolveConfirmation(messageID: UUID, confirmationID: UUID, approve: Bool) {
        guard let mi = note.chatMessages.firstIndex(where: { $0.id == messageID }),
              let ci = note.chatMessages[mi].confirmations?.firstIndex(where: { $0.id == confirmationID }),
              let confirmation = note.chatMessages[mi].confirmations?[ci],
              confirmation.status == .pending else { return }
        
        guard approve else {
            note.chatMessages[mi].confirmations?[ci].status = .cancelled
            return
        }
        note.chatMessages[mi].confirmations?[ci].status = .confirmed
        Task {
            let result = await NotskyAgent.shared.confirm(confirmation)
            guard let mi = note.chatMessages.firstIndex(where: { $0.id == messageID }) else { return }
            if result.succeeded, let action = result.action {
                var actions = note.chatMessages[mi].actions ?? []
                actions.append(action)
                note.chatMessages[mi].actions = actions
            } else if !result.succeeded {
                if let ci = note.chatMessages[mi].confirmations?.firstIndex(where: { $0.id == confirmationID }) {
                    note.chatMessages[mi].confirmations?[ci].status = .cancelled
                }
                note.chatMessages.append(ChatMessage(role: "assistant", content: result.message, isError: true))
                note.chatMessages.capChatHistory(maxStoredMessages)
            }
        }
    }
    
    private func cycleWallpaper() {
        CardWallpaperActions.cycle($note)
    }
    
    private func selectCustomHeaderImage() {
        CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Finder Card Background Image"))
    }
    
    // MARK: - Resize Drag Handles
}
