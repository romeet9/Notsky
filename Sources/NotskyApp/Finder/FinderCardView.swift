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
    @State private var isSearching: Bool = false
    @State private var isHoveringPlus: Bool = false
    @State private var isHoveringTools: Bool = false
    @State private var isHoveringOpenFinder: Bool = false
    @State private var showSettingsPopover: Bool = false
    @State private var apiKeyInput: String = ""
    
    
    // Quick suggestion queries
    private let quickSuggestions = [
        "Find resume PDF",
        "Recent spreadsheets",
        "Recent downloads",
        "Design assets"
    ]
    
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
            // notskyai Title Capsule
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(.red)
                
                Text("notskyai")
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
                    .fill(isSearching ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                
                Text(isSearching ? LocalizedStringKey("thinking") : LocalizedStringKey("ready"))
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
                }
            }) {
                Image(systemName: "plus")
                    .accessibilityLabel("Add")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringPlus), in: Circle())
                    .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPlus = $0 }
            .help("Start New notskyai Chat")
            
            Spacer()
            
            // 4-Icon Action Cluster Pill
            HStack(spacing: 11) {
                // 1. API Key & Model Settings
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    apiKeyInput = AIFinderService.shared.apiKey
                    showSettingsPopover.toggle()
                }) {
                    Image(systemName: "key.fill")
                        .scaledFont(size: 12.5, weight: .medium)
                        .foregroundStyle(AIFinderService.shared.apiKey.isEmpty ? (isDark ? .white.opacity(0.5) : .black.opacity(0.4)) : Color.green)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettingsPopover) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("notskyai Cloud Configuration")
                            .scaledFont(size: 12, weight: .bold)
                        
                        Text("Active Free Model: \(AIFinderService.defaultFreeModel)")
                            .scaledFont(size: 11)
                            .foregroundStyle(.secondary)
                        
                        SecureField("OpenRouter API Key (Optional)", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                        
                        HStack {
                            Button("Save") {
                                AIFinderService.shared.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                showSettingsPopover = false
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Clear") {
                                AIFinderService.shared.apiKey = ""
                                apiKeyInput = ""
                            }
                        }
                    }
                    .padding(14)
                }
                .help("AI Settings")
                
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
                    if note.chatMessages.isEmpty {
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
                            FinderChatMessageRow(msg: message, cardWidth: cardWidth, isDark: isDark, sheetBackgroundColor: sheetBackgroundColor, specularBorderGradient: specularBorderGradient)
                        }
                    }
                    
                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching local storage & reasoning with notskyai...")
                                .scaledFont(size: 13, weight: .regular)
                                .foregroundStyle(isDark ? Color(white: 0.65) : Color(white: 0.45))
                        }
                        .padding(.vertical, 4)
                        .id("searching_indicator")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.bottom, 95)
            }
            .scrollIndicators(.hidden)
            .contentEdgeFade(top: 22, bottom: 44)
            .onChange(of: note.chatMessages.count) {
                if let lastId = note.chatMessages.last?.id {
                    withMotion {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State Intro & Quick Suggestions
    
    // MARK: - Chat Message Row
    
    // MARK: - Square Document Card
    
    
    
    // MARK: - Bottom Floating Bar with Input Bar & Open Finder Button
    private var bottomFloatingBar: some View {
        HStack(spacing: 6) {
            // macOS Spotlight Style Input Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                
                TextField("Ask notskyai or search...", text: $inputText)
                    .textFieldStyle(.plain)
                    .scaledFont(size: 12.5, weight: .regular)
                    .onSubmit {
                        sendMessage()
                    }
                
                if !inputText.isEmpty {
                    Button(action: { sendMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .accessibilityLabel("Send")
                            .scaledFont(size: 18)
                            .foregroundStyle(isDark ? .white : .black)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
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
        guard !trimmed.isEmpty else { return }
        
        SensoryFeedback.buttonClicked()
        inputText = ""
        
        let userMsg = ChatMessage(role: "user", content: trimmed)
        note.chatMessages.append(userMsg)
        isSearching = true
        
        Task {
            // 1. Search local files matching query (natural language date/month parsing is built into the search service)
            let matchedFiles = await AIFinderService.shared.searchLocalFiles(matching: trimmed, maxResults: 5)
            
            // 2. Query notskyai Cloud AI with context
            do {
                let aiResponse = try await AIFinderService.shared.queryCloudAI(
                    userPrompt: trimmed,
                    relevantFiles: matchedFiles,
                    chatHistory: note.chatMessages
                )
                
                await MainActor.run {
                    let assistantMsg = ChatMessage(role: "assistant", content: aiResponse, attachedFiles: matchedFiles)
                    note.chatMessages.append(assistantMsg)
                    isSearching = false
                    SensoryFeedback.timerFinished()
                }
            } catch {
                await MainActor.run {
                    let fallback = AIFinderService.shared.generateLocalFallbackResponse(query: trimmed, files: matchedFiles)
                    let assistantMsg = ChatMessage(role: "assistant", content: fallback, attachedFiles: matchedFiles)
                    note.chatMessages.append(assistantMsg)
                    isSearching = false
                }
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
