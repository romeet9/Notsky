import SwiftUI
import AppKit

@MainActor
public struct FreeformNoteCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = AppSettings.shared
    @Binding public var note: NoteCard
    public var onSpawnWidget: () -> Void
    public var onDelete: () -> Void
    
    @State private var formatController = NoteTextFormatController()
    
    @State private var isEditingTabIndex: Int? = nil
    @FocusState private var isTabFocused: Bool
    @State private var hoveredTabIndex: Int? = nil
    @State private var isHoveringPlusTab: Bool = false
    @State private var isHoveringCard: Bool = false
    @State private var isHoveringBold: Bool = false
    @State private var isHoveringItalic: Bool = false
    @State private var isHoveringBullet: Bool = false
    @State private var isHoveringDownload: Bool = false
    @State private var isDownloaded: Bool = false
    @State private var isHoveringPin: Bool = false
    @State private var isHoveringCycle: Bool = false
    @State private var isHoveringGallery: Bool = false
    @State private var isHoveringTrash: Bool = false
    @State private var isHoveringNewCard: Bool = false
    
    
    // Directional slide animation state for tabs
    @State private var slideDirection: Edge = .trailing
    
    private var showControls: Bool {
        !settings.autoHideControls || isHoveringCard
    }
    
    // Width & Height driven by note model:
    // Default: 281 × 364 pt. Max: 586 × 752 pt.
    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    
    // Spacing between tab cards when sliding
    private let tabGap: CGFloat = 24.0
    
    // Weighted jelly bouncy spring animation for macOS fluid interaction
    private var tabSlideAnimation: Animation {
        .spring(response: 0.44, dampingFraction: 0.64, blendDuration: 0.16)
    }
    
    private let minCardWidth: Double = 281
    private let maxCardWidth: Double = 860
    private let minCardHeight: Double = 260
    private let maxCardHeight: Double = 752
    
    private var contentWidth: CGFloat { max(200, cardWidth - 46) }
    private var toolbarWidth: CGFloat { max(220, cardWidth - 28) }
    
    // MARK: - Adaptive Styling & Optical Depth
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
    
    private var noteFontSize: CGFloat {
        switch settings.interfaceScale {
        case "Small": return 13.5
        case "Large": return 16.5
        default: return 15.0
        }
    }
    
    private var noteTextColor: Color {
        isDark ? Color.white : Color.black
    }
    
    private var placeholderColor: Color {
        isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
    }
    
    private var buttonIconColor: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.75)
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
    
    private var currentPages: [NotePage] {
        if note.pages.isEmpty {
            return [NotePage(title: note.title.isEmpty ? String(localized: "Quick Note") : note.title, content: note.noteContent)]
        }
        return note.pages
    }
    
    private func contentBinding(for index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                if note.pages.indices.contains(index) {
                    return note.pages[index].content
                }
                return note.noteContent
            },
            set: { newValue in
                ensurePagesInitialized()
                if note.pages.indices.contains(index) {
                    note.pages[index].content = newValue
                    if index == note.activePageIndex {
                        note.noteContent = newValue
                    }
                }
            }
        )
    }
    
    private func wordCount(for text: String) -> Int {
        let plain = text.replacing("**", with: "").replacing("*", with: "")
        let words = plain.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }
    
    private func charCount(for text: String) -> Int {
        let plain = text.replacing("**", with: "").replacing("*", with: "")
        return plain.count
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

            // 2. Foreground Content Sheet — Multi-Tab Sliding Track with Distinct Gap & Bouncy Spring
            HStack(spacing: tabGap) {
                ForEach(Array(currentPages.enumerated()), id: \.element.id) { index, page in
                    ZStack(alignment: .top) {
                        // Frosted Glass Tint & Hardware Accelerated Material
                        sheetBackgroundColor
                            .background(.ultraThinMaterial)

                        // Main Notes Content for this tab page
                        VStack(spacing: 0) {
                            topToolbar
                            FreeformEditorPane(noteId: note.id, index: index, text: contentBinding(for: index), noteFontSize: noteFontSize, placeholderColor: placeholderColor, isDark: isDark, formatController: formatController, sheetHeight: sheetHeight, contentWidth: contentWidth, cardWidth: cardWidth)
                            bottomToolbar(for: index)
                        }
                    }
                    .frame(width: cardWidth, height: sheetHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                    )
                }
            }
            .offset(x: -CGFloat(min(note.activePageIndex, max(0, currentPages.count - 1))) * (cardWidth + tabGap))
            .motionAnimation(tabSlideAnimation, value: note.activePageIndex)
            .frame(width: cardWidth, height: sheetHeight, alignment: .leading)
            .offset(y: headerHeight)
            .zIndex(1)

            // 3. Top Title Tab Bar (Tabs + Plus Button) — Centered horizontally
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
        .onAppear {
            ensurePagesInitialized()
        }
        .onHover { hovering in
            withMotion(.spring(response: 0.28, dampingFraction: 0.85)) {
                isHoveringCard = hovering
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

    // MARK: - 1. Top Header Tab Bar (Title Tabs + Plus Button) — Centered
    @ViewBuilder
    private var headerTitleCapsule: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(Array(currentPages.enumerated()), id: \.offset) { index, page in
                    let isActive = (note.activePageIndex == index)
                    let isEditingThisTab = (isEditingTabIndex == index)
                    
                    if isEditingThisTab {
                        HStack(spacing: 4) {
                            TextField("Title", text: Binding(
                                get: { index < note.pages.count ? note.pages[index].title : page.title },
                                set: { val in
                                    ensurePagesInitialized()
                                    if index < note.pages.count { note.pages[index].title = val }
                                }
                            ))
                            .scaledFont(size: 13, weight: .semibold, design: .default)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(taskTextColor)
                            .focused($isTabFocused)
                            .onSubmit {
                                SensoryFeedback.buttonClicked()
                                isEditingTabIndex = nil
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(sheetBackgroundColor, in: Capsule())
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                        .shadow(color: Color.black.opacity(isDark ? 0.04 : 0.02), radius: 3, x: 0, y: 1)
                    } else {
                        Button(action: {
                            ensurePagesInitialized()
                            if isActive {
                                isEditingTabIndex = index
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.05))
                                    isTabFocused = true
                                }
                            } else {
                                isEditingTabIndex = nil
                                let newDirection: Edge = (index > note.activePageIndex) ? .trailing : .leading
                                self.slideDirection = newDirection
                                withMotion(tabSlideAnimation) {
                                    note.activePageIndex = index
                                }
                            }
                            SensoryFeedback.buttonClicked()
                        }) {
                            HStack(spacing: 6) {
                                Text(page.title.isEmpty ? String(localized: "Note \(index + 1)") : page.title)
                                    .scaledFont(size: 13, weight: isActive ? .semibold : .medium, design: .default)
                                    .foregroundStyle(isActive ? taskTextColor : taskTextColor.opacity(0.65))
                                    .lineLimit(1)

                                if note.pages.count > 1 {
                                    Button(action: {
                                        deleteTab(at: index)
                                    }) {
                                        Image(systemName: "xmark")
                                            .scaledFont(size: 9, weight: .bold)
                                            .foregroundStyle(isActive ? taskTextColor.opacity(0.85) : taskTextColor.opacity(0.50))
                                            .frame(width: 14, height: 14)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete Note Tab")
                                    .accessibilityLabel("Delete Note Tab")
                                }
                            }
                            .padding(.horizontal, isActive ? 14 : 12)
                            .frame(height: 36)
                            .background(
                                isActive ? sheetBackgroundColor : sheetBackgroundColor.opacity(0.40),
                                in: Capsule()
                            )
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(isActive ? specularBorderGradient : LinearGradient(colors: [Color.white.opacity(isDark ? 0.12 : 0.35), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: isActive ? 0.75 : 0.5)
                            )
                            .shadow(color: Color.black.opacity(isActive ? (isDark ? 0.04 : 0.02) : 0), radius: 3, x: 0, y: 1)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in
                            hoveredTabIndex = inside ? index : nil
                        }
                        .contextMenu {
                            Button("Rename Tab") {
                                ensurePagesInitialized()
                                isEditingTabIndex = index
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.05))
                                    isTabFocused = true
                                }
                            }
                            if note.pages.count > 1 {
                                Button(role: .destructive, action: {
                                    deleteTab(at: index)
                                }) {
                                    Label("Delete Tab", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Plus (+) Button to Add a New Tab (Max 3 Tabs)
                if canAddTab {
                    Button(action: {
                        addNewTab()
                    }) {
                        Image(systemName: "plus")
                            .accessibilityLabel("New Tab")
                            .scaledFont(size: 12, weight: .bold)
                            .foregroundStyle(buttonIconColor)
                            .frame(width: 36, height: 36)
                            .background(buttonBackgroundColor(hovering: isHoveringPlusTab), in: Circle())
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                            )
                            .shadow(color: Color.black.opacity(isDark ? 0.04 : 0.02), radius: 3, x: 0, y: 1)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPlusTab = $0 }
                    .help("Add New Note Tab")
                }
            }
            .frame(maxWidth: cardWidth - 28, alignment: .center)

            Spacer(minLength: 0)
        }
    }

    private var taskTextColor: Color {
        isDark ? Color.white : Color.black
    }

    // MARK: - 2. Top Toolbar (Top-Left Formatting & Folder Menu + Top-Right Action Capsule)
    @ViewBuilder
    private var topToolbar: some View {
        HStack {
            // Top-Left Formatting Capsule (Bold, Italic, Pointers) — ALWAYS VISIBLE
            HStack(spacing: 12) {
                // Bold Button
                Button(action: {
                    formatActiveContentBold()
                }) {
                    Image(systemName: "bold")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringBold = $0 }
                .help("Bold Text (**bold**)")
                .accessibilityLabel("Bold Text (**bold**)")

                // Italic Button
                Button(action: {
                    formatActiveContentItalic()
                }) {
                    Image(systemName: "italic")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringItalic = $0 }
                .help("Italic Text (*italic*)")
                .accessibilityLabel("Italic Text (*italic*)")

                // Bullet Points Button
                Button(action: {
                    formatActiveContentBullets()
                }) {
                    Image(systemName: "list.bullet")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(buttonIconColor)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringBullet = $0 }
                .help("Add Bullet Points (•)")
                .accessibilityLabel("Add Bullet Points (•)")
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(buttonBackgroundColor(hovering: isHoveringBold || isHoveringItalic || isHoveringBullet), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)

            Spacer()

            // Top-Right Action Buttons Capsule — AUTO-HIDDEN (Slides in from Trailing Edge on Hover)
            if showControls {
                HStack(spacing: 12) {
                    // Download 4K Card Image Button
                    Button(action: {
                        CardActions.download(note: note, isDark: isDark, isDownloaded: $isDownloaded)
                    }) {
                        Image(systemName: isDownloaded ? "checkmark" : "arrow.down.to.line")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(isDownloaded ? Color.green : buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringDownload = $0 }
                    .help(isDownloaded ? LocalizedStringKey("Saved 4K Image to Downloads!") : LocalizedStringKey("Download 4K Image (for LinkedIn, Instagram, Twitter)"))

                    // Pin on Top / Wallpaper Canvas Toggle
                    Button(action: {
                        CardActions.togglePinned($note, haptic: true)
                    }) {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(note.isPinned ? Color.orange : buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPin = $0 }
                    .help(note.isPinned ? LocalizedStringKey("Pinned on Top (Click to stick to Wallpaper)") : LocalizedStringKey("Pin on Top (Float above all windows)"))

                    // Cycle Next Wallpaper in Pack
                    Button(action: {
                        cycleWallpaper()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringCycle = $0 }
                    .help("Next Wallpaper in Pack")
                    .accessibilityLabel("Next Wallpaper in Pack")

                    // Change Header Image / Wallpaper Button
                    Button(action: {
                        SensoryFeedback.buttonClicked()
                        selectCustomHeaderImage()
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(buttonIconColor)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringGallery = $0 }
                    .help("Change Header Image")
                    .accessibilityLabel("Change Header Image")

                    // Delete Button
                    Button(action: {
                        SensoryFeedback.taskDeleted()
                        onDelete()
                    }) {
                        Image(systemName: "trash")
                            .scaledFont(size: 13, weight: .medium)
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
                .motionTransition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .motionAnimation(.spring(response: 0.32, dampingFraction: 0.82), value: showControls)
        .frame(width: toolbarWidth)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - 3. Notes Editor Area (Bound to Tab Index)

    private var canAddTab: Bool {
        note.pages.count < 3
    }

    // MARK: - 4. Bottom Toolbar (Folder Label, Capsule Stats Label & Single Add Card Button)
    @ViewBuilder
    private func bottomToolbar(for index: Int) -> some View {
        let content = note.pages.indices.contains(index) ? note.pages[index].content : ""
        let words = wordCount(for: content)
        let chars = charCount(for: content)
        
        HStack(spacing: 8) {
            // Folder Selection Capsule on the bottom-left opposite Add Card (Solid white background label)
            CardFolderPicker(note: $note)
            .padding(.leading, 16)

            // Word & Character count label inside 38pt Capsule — visible when width permits
            if cardWidth >= 380 || !showControls {
                HStack(spacing: 4) {
                    Text("\(words) words, \(chars) characters")
                        .scaledFont(size: 12, weight: .medium, design: .default)
                        .foregroundStyle(taskTextColor.opacity(0.88))
                }
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(sheetBackgroundColor, in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.05 : 0.035), radius: 4, x: 0, y: 1)
            }

            Spacer()

            // Single Direct "Add Card" Button — AUTO-HIDDEN (Slides in from Trailing Edge on Hover)
            if showControls {
                Button(action: {
                    SensoryFeedback.widgetSpawned()
                    if let origin = WidgetWindowManager.shared.windowOrigin(for: note.id) {
                        WidgetWindowManager.shared.spawnNewFreeformNoteWidget(near: origin)
                    } else {
                        WidgetWindowManager.shared.spawnNewFreeformNoteWidget()
                    }
                }) {
                    Text("Add Card")
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
                .help("Add New Freeform Note Card")
                .padding(.trailing, 16)
                .motionTransition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .motionAnimation(.spring(response: 0.32, dampingFraction: 0.82), value: showControls)
        .frame(width: cardWidth)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }

    // MARK: - Multi-Tab Actions
    private func ensurePagesInitialized() {
        if note.pages.isEmpty {
            note.pages = [NotePage(title: "Note 1", content: note.noteContent)]
            note.activePageIndex = 0
        }
    }
    
    private func addNewTab() {
        ensurePagesInitialized()
        guard note.pages.count < 3 else { return }
        let nextIndex = note.pages.count + 1
        let title = "Note \(nextIndex)"
        let newPage = NotePage(title: title, content: "")
        self.slideDirection = .trailing
        withMotion(tabSlideAnimation) {
            note.pages.append(newPage)
            note.activePageIndex = note.pages.count - 1
            isEditingTabIndex = nil
        }
        SensoryFeedback.buttonClicked()
    }
    
    private func deleteTab(at index: Int) {
        ensurePagesInitialized()
        guard note.pages.count > 1, note.pages.indices.contains(index) else { return }
        self.slideDirection = .leading
        withMotion(tabSlideAnimation) {
            note.pages.remove(at: index)
            if note.activePageIndex >= note.pages.count {
                note.activePageIndex = max(0, note.pages.count - 1)
            }
        }
        SensoryFeedback.taskDeleted()
    }
    
    private func formatActiveContentBold() {
        if note.pages.indices.contains(note.activePageIndex) {
            formatController.toggleBold(in: &note.pages[note.activePageIndex].content)
        } else {
            formatController.toggleBold(in: &note.noteContent)
        }
    }
    
    private func formatActiveContentItalic() {
        if note.pages.indices.contains(note.activePageIndex) {
            formatController.toggleItalic(in: &note.pages[note.activePageIndex].content)
        } else {
            formatController.toggleItalic(in: &note.noteContent)
        }
    }
    
    private func formatActiveContentBullets() {
        if note.pages.indices.contains(note.activePageIndex) {
            formatController.toggleBullets(in: &note.pages[note.activePageIndex].content)
        } else {
            formatController.toggleBullets(in: &note.noteContent)
        }
    }


    // MARK: - Helpers
    private func cycleWallpaper() {
        CardWallpaperActions.cycle($note)
    }

    private func selectCustomHeaderImage() {
        CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Note Card Background Image"))
    }

    // MARK: - 5. Resize Drag Handles
}
