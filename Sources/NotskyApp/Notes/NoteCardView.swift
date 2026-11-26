import SwiftUI
import AppKit

@MainActor
public struct NoteCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = AppSettings.shared
    @Binding public var note: NoteCard
    public var onSpawnWidget: () -> Void
    public var onDelete: () -> Void
    /// Only one view per note may tick the focus timer (the drawer renders the same notes as the widget windows).
    public var ticksTimer: Bool = true
    
    @State private var isEditingTitle: Bool = false
    @FocusState private var isTitleFocused: Bool
    @State private var isLightHeader: Bool = false
    @State private var isHoveringCard: Bool = false
    @State private var isHoveringPlus: Bool = false
    @State private var isHoveringTimer: Bool = false
    @State private var isHoveringDownload: Bool = false
    @State private var isDownloaded: Bool = false
    @State private var isHoveringPin: Bool = false
    @State private var isHoveringCycle: Bool = false
    @State private var isHoveringGallery: Bool = false
    @State private var isHoveringTrash: Bool = false
    @State private var isHoveringNewCard: Bool = false
    
    private var showControls: Bool {
        !settings.autoHideControls || isHoveringCard
    }
    
    
    // New task creation state
    @State private var isAddingTask: Bool = false
    @State private var newTaskText: String = ""
    @FocusState private var isInputFocused: Bool
    
    private func tickTimer() {
        guard ticksTimer, note.isTimerRunning else { return }
        if note.timeRemaining > 0 {
            note.timeRemaining -= 1
        } else {
            note.isTimerRunning = false
            SensoryFeedback.timerFinished()
            note.timeRemaining = note.timerDuration
        }
    }
    
    private var timeString: String {
        note.timeRemaining.minutesSecondsString
    }
    
    private func toggleTimer() {
        SensoryFeedback.buttonClicked()
        withMotion(.spring(response: 0.25, dampingFraction: 0.8)) {
            note.isTimerRunning.toggle()
        }
        if note.isTimerRunning {
            SensoryFeedback.timerStarted()
            NotificationCenter.default.post(name: .notskyTimerStarted, object: note.id)
        } else {
            SensoryFeedback.timerPaused()
        }
    }
    
    // Width & Height driven by note model with grid constraints:
    // Default: 281 × 364 pt. Spacing: 24 pt.
    // Max Width: 281 * 2 + 24 = 586 pt.
    // Max Height: 364 * 2 + 24 = 752 pt.
    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    
    private let minCardWidth: Double = 281
    private let maxCardWidth: Double = 586
    private let minCardHeight: Double = 364
    private let maxCardHeight: Double = 752
    
    // Content width inside the card
    private var contentWidth: CGFloat { max(200, cardWidth - 46) }
    private var toolbarWidth: CGFloat { max(220, cardWidth - 28) }
    
    // MARK: - Adaptive Styling & 3D macOS Optical Depth
    private var isDark: Bool {
        if let override = settings.preferredColorScheme {
            return override == .dark
        }
        return colorScheme == .dark
    }
    
    // Shared background used on BOTH the main card and the top title label
    private var sheetBackgroundColor: Color {
        let opacity = settings.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }
    
    private var taskFontSize: CGFloat {
        switch settings.interfaceScale {
        case "Small": return 13.5
        case "Large": return 16.5
        default: return 15.0
        }
    }
    
    private var taskRowSpacing: CGFloat {
        switch settings.interfaceScale {
        case "Small": return 10.0
        case "Large": return 18.0
        default: return 14.0
        }
    }
    
    private var taskTextColor: Color {
        isDark ? Color.white : Color.black
    }
    
    private var dynamicAccentColor: Color {
        ImageLuminanceDetector.dominantAccentColor(at: note.headerImagePath)
    }
    
    private var completedTaskColor: Color {
        isDark ? Color(white: 0.45) : Color(red: 0.83, green: 0.83, blue: 0.83)
    }
    
    private var buttonIconColor: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.75)
    }
    
    // Exact same frosted glass formula as the main background rectangle
    private func buttonBackgroundColor(hovering: Bool) -> Color {
        if isDark {
            return hovering ? Color(white: 0.16).opacity(0.90) : sheetBackgroundColor
        } else {
            return hovering ? Color.white.opacity(0.98) : sheetBackgroundColor
        }
    }
    
    // Specular light gradient border catching top ambient light (classic macOS 3D bevel effect)
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
    
    private var timerHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.40)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public init(
        note: Binding<NoteCard>,
        onSpawnWidget: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {},
        ticksTimer: Bool = true
    ) {
        self._note = note
        self.onSpawnWidget = onSpawnWidget
        self.onDelete = onDelete
        self.ticksTimer = ticksTimer
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
                VStack(spacing: 0) {
                    if showControls || isAddingTask {
                        topToolbar
                            .motionTransition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    if isAddingTask {
                        NoteTaskInputField(nextIndex: note.items.count + 1, accentColor: dynamicAccentColor, taskTextColor: taskTextColor, contentWidth: contentWidth, text: $newTaskText, isFocused: $isInputFocused, onSubmit: commitNewTask)
                            .motionTransition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    NoteTaskList(note: $note, taskTextColor: taskTextColor, completedTaskColor: completedTaskColor, accentColor: dynamicAccentColor, isDark: isDark, fontSize: taskFontSize, rowSpacing: taskRowSpacing, contentWidth: contentWidth, cardWidth: cardWidth, showControls: showControls, isAddingTask: isAddingTask)

                    if showControls && !isAddingTask {
                        bottomToolbar
                            .motionTransition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .motionAnimation(.spring(response: 0.32, dampingFraction: 0.82), value: showControls || isAddingTask)
            }
            .frame(width: cardWidth, height: sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .offset(y: headerHeight)
            .zIndex(1)

            // 3. Top Title & Ambient Focus Capsule — Elevated zIndex for direct click handling
            headerTitleCapsule
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)

            // 4. Resize Drag Handles — Elevated above all content to ensure instant edge grabbing
            CardResizeHandles(
                note: $note,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                widthRange: minCardWidth...maxCardWidth,
                heightRange: minCardHeight...maxCardHeight
            )
                .zIndex(100)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.20), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.08 : 0.04), radius: 6, x: 0, y: 2)
        .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onHover { hovering in
            withMotion(.spring(response: 0.28, dampingFraction: 0.85)) {
                isHoveringCard = hovering
            }
        }
        .onAppear {
            updateLuminance()
        }
        .onChange(of: note.headerImagePath) { _, _ in
            updateLuminance()
        }
        .task(id: ticksTimer && note.isTimerRunning) {
            guard ticksTimer, note.isTimerRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                tickTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notskyTimerStarted)) { notification in
            if let activeNoteId = notification.object as? UUID, activeNoteId != note.id {
                if note.isTimerRunning {
                    withMotion(.spring(response: 0.25, dampingFraction: 0.85)) {
                        note.isTimerRunning = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notskyTimerStarted)) { notification in
            if let activeNoteId = notification.object as? UUID, activeNoteId != note.id {
                if note.isTimerRunning {
                    withMotion(.spring(response: 0.25, dampingFraction: 0.85)) {
                        note.isTimerRunning = false
                    }
                }
            }
        }
        .contextMenu {
            CardContextMenu(
                note: $note,
                isDownloaded: $isDownloaded,
                isDark: isDark,
                onChangeHeaderImage: selectCustomHeaderImage,
                onDelete: onDelete
            )
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerTitleCapsule: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                // Section 1: Note Title Capsule
                HStack(spacing: 4) {
                    if isEditingTitle {
                        TextField("Title", text: $note.title)
                            .scaledFont(size: 13, weight: .medium, design: .default)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(taskTextColor)
                            .focused($isTitleFocused)
                            .onSubmit {
                                SensoryFeedback.buttonClicked()
                                isEditingTitle = false
                            }
                    } else {
                        Text(note.title.isEmpty ? String(localized: "Title") : note.title)
                            .scaledFont(size: 13, weight: .medium, design: .default)
                            .foregroundStyle(taskTextColor)
                            .lineLimit(1)
                            .onTapGesture {
                                isEditingTitle = true
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.05))
                                    isTitleFocused = true
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(sheetBackgroundColor, in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                .contentShape(Capsule())

                // Section 2: Independent Per-Group Focus Timer Pill (Always Visible)
                Button(action: {
                    toggleTimer()
                }) {
                    HStack(spacing: 6) {
                        RemixImage(note.isTimerRunning ? .pauseFill : .playFill, scaledSize: 11.5, accessibilityLabel: note.isTimerRunning ? LocalizedStringKey("Pause Timer") : LocalizedStringKey("Start Timer"))
                            .foregroundStyle(note.isTimerRunning ? Color.orange : buttonIconColor)
                        
                        Text(timeString)
                            .scaledFont(size: 13, weight: .semibold, design: .rounded)
                            .monospacedDigit()
                            .foregroundStyle(note.isTimerRunning ? (isDark ? Color.white : Color.orange) : taskTextColor.opacity(0.88))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringTimer), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(note.isTimerRunning ? timerHighlightGradient : specularBorderGradient, lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { isHoveringTimer = $0 }
                .help(note.isTimerRunning ? LocalizedStringKey("Click to Pause") : LocalizedStringKey("Click to Start Focus Session"))
            }
            .frame(maxWidth: cardWidth - 28)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var topToolbar: some View {
        HStack {
            // Left (+) Button (40 × 40 pt)
            Button(action: toggleTaskInput) {
                RemixImage(isAddingTask ? .closeLine : .addLine, scaledSize: 17.5)
                    .foregroundStyle(buttonIconColor)
                    .frame(width: 40, height: 40)
                    .background(buttonBackgroundColor(hovering: isHoveringPlus), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPlus = $0 }
            .help("Add Task Item")

            Spacer()

            // Right Button Group — 3D Frosted Group
            HStack(spacing: 12) {
                // Download 4K Card Image Button
                Button(action: {
                    CardActions.download(note: note, isDark: isDark, isDownloaded: $isDownloaded)
                }) {
                    RemixImage(isDownloaded ? .checkLine : .downloadLine, scaledSize: 15)
                        .foregroundStyle(isDownloaded ? Color.green : buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringDownload = $0 }
                .help(isDownloaded ? LocalizedStringKey("Saved 4K Image to Downloads!") : LocalizedStringKey("Download 4K Image"))

                // Pin on Top / Wallpaper Canvas Toggle
                Button(action: {
                    CardActions.togglePinned($note, haptic: true)
                }) {
                    RemixImage(note.isPinned ? .pushpinFill : .pushpinLine, scaledSize: 15)
                        .foregroundStyle(note.isPinned ? Color.orange : buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringPin = $0 }
                .help(note.isPinned ? LocalizedStringKey("Pinned on Top (Click to stick to Wallpaper)") : LocalizedStringKey("Pin on Top"))

                // Cycle Next Wallpaper in Pack
                Button(action: {
                    cycleWallpaper()
                }) {
                    RemixImage(.refreshLine, scaledSize: 15)
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCycle = $0 }
                .help("Next Wallpaper in Pack")
                .accessibilityLabel("Next Wallpaper in Pack")

                Button(action: {
                    SensoryFeedback.buttonClicked()
                    selectCustomHeaderImage()
                }) {
                    RemixImage(.imageLine, scaledSize: 15)
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringGallery = $0 }
                .help("Change Header Image")
                .accessibilityLabel("Change Header Image")

                Button(action: {
                    SensoryFeedback.taskDeleted()
                    onDelete()
                }) {
                    RemixImage(.deleteBinLine, scaledSize: 15)
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringTrash = $0 }
                .help("Delete Note Widget")
                .accessibilityLabel("Delete Note Widget")
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(buttonBackgroundColor(hovering: isHoveringDownload || isHoveringPin || isHoveringCycle || isHoveringGallery || isHoveringTrash), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
        }
        .frame(width: toolbarWidth)
        .padding(.top, 12)
        .padding(.bottom, isAddingTask ? 4 : 4)
    }



    @ViewBuilder
    private var bottomToolbar: some View {
        HStack {
            // Folder Selection Capsule on the bottom-left opposite Add Group (Solid white background label)
            CardFolderPicker(note: $note)
            .padding(.leading, 16)

            Spacer()

            // Single Direct "Add Group" Button
            Button(action: {
                SensoryFeedback.widgetSpawned()
                onSpawnWidget()
            }) {
                Text("Add Group")
                    .scaledFont(size: 13, weight: .medium, design: .default)
                    .foregroundStyle(buttonIconColor)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(buttonBackgroundColor(hovering: isHoveringNewCard), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringNewCard = $0 }
            .help("Create New Note Group / Widget")
            .padding(.trailing, 16)
        }
        .frame(width: cardWidth)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }


    private func toggleTaskInput() {
        SensoryFeedback.buttonClicked()
        withMotion(.easeInOut(duration: 0.2)) {
            isAddingTask.toggle()
            if isAddingTask {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.05))
                    isInputFocused = true
                }
            } else {
                newTaskText = ""
            }
        }
    }

    private func commitNewTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let newItem = NoteItem(text: trimmed, isCompleted: false)
            note.items.insert(newItem, at: 0)
            SensoryFeedback.taskAdded()
        }
        newTaskText = ""
        withMotion(.easeInOut(duration: 0.2)) {
            isAddingTask = false
        }
    }

    private func updateLuminance() {
        let path = note.headerImagePath
        Task.detached(priority: .userInitiated) {
            let isLight = ImageLuminanceDetector.isLightImage(at: path)
            Task { @MainActor in
                self.isLightHeader = isLight
            }
        }
    }

    private func cycleWallpaper() {
        CardWallpaperActions.cycle($note)
    }

    private func selectCustomHeaderImage() {
        CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Task Card Background Image"))
    }
}
