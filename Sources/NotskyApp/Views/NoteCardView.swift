import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let notskyTimerStarted = Notification.Name("com.notsky.timerStarted")
}

public enum PomodoroPreset: String, CaseIterable {
    case focus = "Focus"
    case shortBreak = "Break"
    case longBreak = "Rest"
    
    public var title: String {
        switch self {
        case .focus: return "25m Focus"
        case .shortBreak: return "5m Break"
        case .longBreak: return "15m Rest"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .focus: return "25m"
        case .shortBreak: return "5m"
        case .longBreak: return "15m"
        }
    }
    
    public var icon: String {
        switch self {
        case .focus: return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "bed.double.fill"
        }
    }
    
    public var durationSeconds: Int {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}

@MainActor
public struct NoteCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = AppSettings.shared
    @Binding public var note: NoteCard
    public var onSpawnWidget: () -> Void
    public var onDelete: () -> Void
    
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
    @State private var isHoveringResizeW: Bool = false
    @State private var isHoveringResizeH: Bool = false
    @State private var isHoveringResizeCorner: Bool = false
    
    private var showControls: Bool {
        !settings.autoHideControls || isHoveringCard
    }
    
    // Drag initial dimensions for smooth resizing
    @State private var dragInitialWidth: Double? = nil
    @State private var dragInitialHeight: Double? = nil
    
    // New task creation state
    @State private var isAddingTask: Bool = false
    @State private var newTaskText: String = ""
    @FocusState private var isInputFocused: Bool
    
    private static let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var timeString: String {
        let m = note.timeRemaining / 60
        let s = note.timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func toggleTimer() {
        SensoryFeedback.buttonClicked()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
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

                // Frosted Glass Tint & System Material
                sheetBackgroundColor
                    .background(.ultraThinMaterial)

                // Main Sheet Content
                VStack(spacing: 0) {
                    if showControls || isAddingTask {
                        topToolbar
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    if isAddingTask {
                        taskInputField
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    taskListView

                    if showControls && !isAddingTask {
                        bottomToolbar
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showControls || isAddingTask)
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
            resizeHandles
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                isHoveringCard = hovering
            }
        }
        .onAppear {
            updateLuminance()
        }
        .onChange(of: note.headerImagePath) { _, _ in
            updateLuminance()
        }
        .onReceive(Self.timerPublisher) { _ in
            guard note.isTimerRunning else { return }
            if note.timeRemaining > 0 {
                note.timeRemaining -= 1
            } else {
                note.isTimerRunning = false
                SensoryFeedback.timerFinished()
                note.timeRemaining = note.timerDuration
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notskyTimerStarted)) { notification in
            if let activeNoteId = notification.object as? UUID, activeNoteId != note.id {
                if note.isTimerRunning {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        note.isTimerRunning = false
                    }
                }
            }
        }
        .contextMenu {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isDownloaded = true
                }
                CardImageExporter.downloadCardImage(note: note, isDark: isDark)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDownloaded = false
                    }
                }
            }) {
                Label("Download 4K Card Image (Downloads)", systemImage: "arrow.down.to.line")
            }
            
            Button(action: {
                CardImageExporter.saveCardImageAs(note: note, isDark: isDark)
            }) {
                Label("Save 4K Card Image As...", systemImage: "square.and.arrow.down")
            }
            
            Divider()
            
            Button(action: {
                selectCustomHeaderImage()
            }) {
                Label("Change Header Image...", systemImage: "photo.on.rectangle")
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    note.isPinned.toggle()
                    WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                }
            }) {
                Label(note.isPinned ? "Unpin (Wallpaper Canvas Mode)" : "Pin on Top (Floating)", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                SensoryFeedback.taskDeleted()
                onDelete()
            }) {
                Label("Delete Note Widget", systemImage: "trash")
            }
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
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(taskTextColor)
                            .focused($isTitleFocused)
                            .onSubmit {
                                SensoryFeedback.buttonClicked()
                                isEditingTitle = false
                            }
                    } else {
                        Text(note.title.isEmpty ? "Title" : note.title)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(taskTextColor)
                            .lineLimit(1)
                            .onTapGesture {
                                isEditingTitle = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isTitleFocused = true
                                }
                            }
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
                        Image(systemName: note.isTimerRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(note.isTimerRunning ? Color.orange : buttonIconColor)
                        
                        Text(timeString)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                .help(note.isTimerRunning ? "Click to Pause" : "Click to Start Focus Session")
            }
            .frame(maxWidth: cardWidth - 28)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var topToolbar: some View {
        HStack {
            // Left (+) Button (40 × 40 pt)
            Button(action: {
                SensoryFeedback.buttonClicked()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAddingTask.toggle()
                    if isAddingTask {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isInputFocused = true
                        }
                    } else {
                        newTaskText = ""
                    }
                }
            }) {
                Image(systemName: isAddingTask ? "xmark" : "plus")
                    .font(.system(size: 15, weight: .medium))
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
                // Download 4K Card Image Button (Universal 2400 × 2400 px for LinkedIn, Instagram, Twitter)
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        isDownloaded = true
                    }
                    CardImageExporter.downloadCardImage(note: note, isDark: isDark)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDownloaded = false
                        }
                    }
                }) {
                    Image(systemName: isDownloaded ? "checkmark" : "arrow.down.to.line")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isDownloaded ? Color.green : buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringDownload = $0 }
                .help(isDownloaded ? "Saved 4K Image to Downloads!" : "Download 4K Image (for LinkedIn, Instagram, Twitter)")

                // Pin on Top / Wallpaper Canvas Toggle
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        note.isPinned.toggle()
                        WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                    }
                }) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(note.isPinned ? Color.orange : buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringPin = $0 }
                .help(note.isPinned ? "Pinned on Top (Click to stick to Wallpaper)" : "Pin on Top (Float above all windows)")

                // Cycle Next Wallpaper in Pack
                Button(action: {
                    cycleWallpaper()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCycle = $0 }
                .help("Next Wallpaper in Pack")

                Button(action: {
                    SensoryFeedback.buttonClicked()
                    selectCustomHeaderImage()
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringGallery = $0 }
                .help("Change Header Image")

                Button(action: {
                    SensoryFeedback.taskDeleted()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringTrash = $0 }
                .help("Delete Note Widget")
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
    private var taskInputField: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(note.items.count + 1).")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(dynamicAccentColor.opacity(0.85))
                .frame(minWidth: 18, alignment: .leading)
                .padding(.top, 1)

            TextField("Write your task", text: $newTaskText)
                .font(.system(size: 15, weight: .regular, design: .default))
                .tracking(-0.4)
                .textFieldStyle(.plain)
                .foregroundStyle(taskTextColor)
                .focused($isInputFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit {
                    commitNewTask()
                }
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.vertical, 4)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }

    @ViewBuilder
    private var taskListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: taskRowSpacing) {
                if note.items.isEmpty && !isAddingTask {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No tasks yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(taskTextColor.opacity(0.65))
                        Text("Click + to add your first task")
                            .font(.system(size: 12.5, weight: .regular))
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
                            accentColor: dynamicAccentColor,
                            isDark: isDark,
                            fontSize: taskFontSize,
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
        .frame(width: cardWidth)
        .frame(maxHeight: .infinity)
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
                .frame(height: 12)

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
                .frame(height: 16)
            }
        )
    }

    @ViewBuilder
    private var bottomToolbar: some View {
        HStack {
            Spacer()
            // Single Direct "Add Group" Button
            Button(action: {
                SensoryFeedback.widgetSpawned()
                onSpawnWidget()
            }) {
                Text("Add Group")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(buttonIconColor)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
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

    @ViewBuilder
    private var resizeHandles: some View {
        // Right Edge
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
                            let newW = max(minCardWidth, min(maxCardWidth, base + Double(value.translation.width)))
                            if abs(note.width - newW) >= 0.5 {
                                note.width = newW
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: note.height)
                            }
                        }
                        .onEnded { _ in
                            dragInitialWidth = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeW = inside
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topTrailing)

        // Bottom Edge
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
                            let newH = max(minCardHeight, min(maxCardHeight, base + Double(value.translation.height)))
                            if abs(note.height - newH) >= 0.5 {
                                note.height = newH
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: note.width, newHeight: newH)
                            }
                        }
                        .onEnded { _ in
                            dragInitialHeight = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeH = inside
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomLeading)

        // Bottom-Right Corner
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
                                let newW = max(minCardWidth, min(maxCardWidth, baseW + Double(value.translation.width)))
                                let newH = max(minCardHeight, min(maxCardHeight, baseH + Double(value.translation.height)))
                                if abs(note.width - newW) >= 0.5 || abs(note.height - newH) >= 0.5 {
                                    note.width = newW
                                    note.height = newH
                                    WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: newH)
                                }
                            }
                            .onEnded { _ in
                                dragInitialWidth = nil
                                dragInitialHeight = nil
                                SensoryFeedback.buttonClicked()
                            }
                    )
                    .onHover { inside in
                        isHoveringResizeCorner = inside
                        if inside {
                            NSCursor.crosshair.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomTrailing)
    }

    private func commitNewTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let newItem = NoteItem(text: trimmed, isCompleted: false)
            note.items.insert(newItem, at: 0)
            SensoryFeedback.taskAdded()
        }
        newTaskText = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            isAddingTask = false
        }
    }

    private func updateLuminance() {
        let path = note.headerImagePath
        DispatchQueue.global(qos: .userInitiated).async {
            let isLight = ImageLuminanceDetector.isLightImage(at: path)
            DispatchQueue.main.async {
                self.isLightHeader = isLight
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
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .heic, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            note.headerImagePath = url.path
        }
    }
}

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
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    item.isCompleted 
                        ? completedTaskColor.opacity(isDark ? 0.75 : 0.65)
                        : (isHoveringRow ? accentColor : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40)))
                )
                .frame(minWidth: 18, alignment: .leading)
                .padding(.top, 1)
            
            Text(item.text)
                .font(.system(size: fontSize, weight: .regular, design: .default))
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                item.isCompleted.toggle()
            }
            if item.isCompleted {
                SensoryFeedback.taskCompleted()
            } else {
                SensoryFeedback.taskUnchecked()
            }
        }
        .contextMenu {
            Button("Delete Task") {
                withAnimation {
                    onDelete()
                }
                SensoryFeedback.taskDeleted()
            }
        }
    }
}

