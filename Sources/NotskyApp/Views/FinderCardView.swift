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
                // Frosted Blurred Wallpaper Underlay
                HeaderImageView(imagePath: note.headerImagePath)
                    .frame(width: cardWidth, height: cardHeight)
                    .offset(y: -headerHeight)
                    .blur(radius: 35)
                    .scaleEffect(1.12)
                    .saturation(1.25)
                    .contrast(1.05)
                    .frame(width: cardWidth, height: sheetHeight)
                    .clipped()
                
                // Frosted Glass Material
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
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    // MARK: - Header Capsules
    private var headerTitleCapsules: some View {
        HStack(spacing: 8) {
            // notskyai Title Capsule
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                
                Text("notskyai")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDark ? .white : .black)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: false), in: Capsule())
            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
            
            // Status Capsule
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                
                Text("ready")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: false), in: Capsule())
            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            // Plus / New Chat Button (40 × 40 pt)
            Button(action: {
                SensoryFeedback.buttonClicked()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    note.chatMessages.removeAll()
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isDark ? .white.opacity(0.9) : .black.opacity(0.75))
                    .frame(width: 40, height: 40)
                    .background(buttonBackgroundColor(hovering: isHoveringPlus), in: Circle())
                    .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPlus = $0 }
            .help("Start New notskyai Chat")
            
            Spacer()
            
            // 4-Icon Action Cluster Pill
            HStack(spacing: 14) {
                // 1. API Key & Model Settings
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    apiKeyInput = AIFinderService.shared.apiKey
                    showSettingsPopover.toggle()
                }) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AIFinderService.shared.apiKey.isEmpty ? .red : (isDark ? .white.opacity(0.85) : .black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettingsPopover) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("notskyai Cloud Configuration")
                            .font(.system(size: 12, weight: .bold))
                        
                        Text("Active Free Model: \(AIFinderService.defaultFreeModel)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
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
                
                // 2. Pin Button
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    note.isPinned.toggle()
                }) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(note.isPinned ? .red : (isDark ? .white.opacity(0.85) : .black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .help("Pin Widget")
                
                // 3. Cycle Wallpaper Button
                Button(action: {
                    cycleWallpaper()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Next Wallpaper in Pack")
                
                // 4. Custom Header Image / Wallpaper Picker
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    selectCustomHeaderImage()
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Change Header Image")
                
                // 5. Trash / Delete Button
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Delete Widget")
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(buttonBackgroundColor(hovering: isHoveringTools), in: Capsule())
            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            .onHover { isHoveringTools = $0 }
        }
    }
    
    // MARK: - Chat Scroll View
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if note.chatMessages.isEmpty {
                        emptyStateIntro
                    } else {
                        ForEach(note.chatMessages) { message in
                            chatMessageRow(message)
                        }
                    }
                    
                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching local storage & reasoning with notskyai...")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(isDark ? Color(white: 0.65) : Color(white: 0.45))
                        }
                        .padding(.vertical, 4)
                        .id("searching_indicator")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.bottom, 95)
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.0), location: 0.0),
                            .init(color: Color.black.opacity(1.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 22)

                    Rectangle()
                        .fill(Color.black)

                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(1.0), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 44)
                }
            )
            .onChange(of: note.chatMessages.count) {
                if let lastId = note.chatMessages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State Intro & Quick Suggestions
    private var emptyStateIntro: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                Text("notskyai Local Finder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isDark ? .white : .black)
            }
            
            Text("Search, analyze, and query documents across your Mac: PDFs, spreadsheets, Word docs, code, and images.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isDark ? .white.opacity(0.6) : .black.opacity(0.6))
                .lineLimit(3)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Searches:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDark ? .white.opacity(0.65) : .black.opacity(0.6))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(quickSuggestions, id: \.self) { suggestion in
                        SuggestedSearchCapsuleButton(
                            text: suggestion,
                            isDark: isDark,
                            specularBorderGradient: specularBorderGradient,
                            action: {
                                inputText = suggestion
                                sendMessage()
                            }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Chat Message Row
    @ViewBuilder
    private func chatMessageRow(_ msg: ChatMessage) -> some View {
        if msg.role == "user" {
            HStack {
                Spacer(minLength: 40)
                Text(msg.content)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDark ? .white : .black)
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
            VStack(alignment: .leading, spacing: 12) {
                if !msg.content.isEmpty {
                    Text(msg.content)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundColor(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                }
                
                if !msg.attachedFiles.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(msg.attachedFiles) { file in
                            fileConceptASquareCard(file)
                        }
                    }
                }
            }
            .id(msg.id)
        }
    }
    
    // MARK: - Square Document Card
    private func fileConceptASquareCard(_ file: FinderFileItem) -> some View {
        Button(action: {
            SensoryFeedback.buttonClicked()
            let url = URL(fileURLWithPath: file.path)
            NSWorkspace.shared.open(url)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Image(systemName: fileIconName(for: file.fileType))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(fileBadgeColor(for: file.fileType))
                    
                    Spacer(minLength: 4)
                    
                    if !file.fileSize.isEmpty {
                        Text(file.fileSize)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    }
                }
                
                Spacer(minLength: 10)
                
                HStack(alignment: .bottom, spacing: 6) {
                    Text(file.name)
                        .font(.system(size: 14.5, weight: .regular, design: .default))
                        .tracking(-0.35)
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                    
                    if !file.formattedDate.isEmpty {
                        Text(file.formattedDate)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.50))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 135, maxHeight: 145)
            .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 5, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }
        }
        .help("Click to open \(file.name)")
    }
    
    private func fileIconName(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.text.fill"
        case "xlsx", "xls", "csv", "numbers": return "tablecells.fill"
        case "docx", "doc", "pages", "txt", "rtf": return "doc.fill"
        case "png", "jpg", "jpeg", "heic", "webp": return "photo.fill"
        case "swift", "py", "js", "ts", "json", "html", "css", "md": return "curlybraces"
        default: return "doc.fill"
        }
    }
    
    private func fileBadgeColor(for ext: String) -> Color {
        switch ext.lowercased() {
        case "pdf": return Color.red.opacity(0.85)
        case "xlsx", "xls", "csv", "numbers": return Color(white: 0.75)
        case "docx", "doc", "pages": return Color(white: 0.70)
        case "png", "jpg", "jpeg", "heic", "webp": return Color(white: 0.65)
        case "swift", "py", "js", "ts", "json", "html", "css", "md": return Color.red.opacity(0.75)
        default: return Color.gray.opacity(0.85)
        }
    }
    
    // MARK: - Bottom Floating Bar with Input Bar & Open Finder Button
    private var bottomFloatingBar: some View {
        HStack(spacing: 8) {
            // macOS Spotlight Style Input Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                
                TextField("Ask notskyai or search files...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .onSubmit {
                        sendMessage()
                    }
                
                if !inputText.isEmpty {
                    Button(action: { sendMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isDark ? .white : .black)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                isDark ? Color(white: 0.16).opacity(0.88) : Color.white.opacity(0.88),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 8, x: 0, y: 2)
            
            // "Open Finder" CTA Button (Height 44pt)
            Button(action: {
                SensoryFeedback.buttonClicked()
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
            }) {
                Text("Open Finder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDark ? .white.opacity(0.95) : .black.opacity(0.9))
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(
                        isDark ? Color(white: 0.18).opacity(isHoveringOpenFinder ? 0.95 : 0.88) : Color.white.opacity(isHoveringOpenFinder ? 0.95 : 0.88),
                        in: Capsule()
                    )
                    .background(.thinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                    .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringOpenFinder = $0 }
            .help("Open macOS Finder")
        }
        .padding(.horizontal, 16)
        .padding(.top, 36)
        .padding(.bottom, 16)
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
        SensoryFeedback.buttonClicked()
        let nextPath = WallpaperPackManager.shared.cycleNextWallpaper(after: note.headerImagePath)
        withAnimation(.easeInOut(duration: 0.2)) {
            note.headerImagePath = nextPath
        }
    }
    
    private func selectCustomHeaderImage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image, .heic, .png, .jpeg]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Select Finder Card Background Image"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                note.headerImagePath = url.path
            }
            SensoryFeedback.buttonClicked()
        }
    }
}

// MARK: - White Frosted Glass Suggested Search Button (Matching Open Finder & Labels)

private struct SuggestedSearchCapsuleButton: View {
    let text: String
    let isDark: Bool
    let specularBorderGradient: LinearGradient
    let action: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: {
            SensoryFeedback.buttonClicked()
            action()
        }) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.7))
                
                Text(text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(isDark ? .white.opacity(0.95) : .black.opacity(0.9))
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                isDark ? Color.white.opacity(isHovering ? 0.24 : 0.16) : Color(white: 0.88).opacity(isHovering ? 0.96 : 0.85),
                in: Capsule()
            )
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.05), radius: 6, x: 0, y: 1.5)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
