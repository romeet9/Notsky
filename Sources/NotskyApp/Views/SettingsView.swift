import SwiftUI
import AppKit

public enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    // General
    case general = "General"
    case sensory = "Sensory Feedback"
    
    // Widgets
    case widgets = "Desktop Widgets"
    case appearance = "Appearance & Packs"
    
    // Features
    case focusTimer = "Focus Timer"
    case exportSharing = "4K Export & Share"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .sensory: return "waveform"
        case .widgets: return "square.grid.2x2"
        case .appearance: return "paintpalette"
        case .focusTimer: return "timer"
        case .exportSharing: return "square.and.arrow.up"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}

public struct SettingsView: View {
    @Binding public var selectedItem: SettingsSidebarItem
    @State private var searchText: String = ""
    @Bindable private var settings = AppSettings.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared
    
    public init(selectedItem: Binding<SettingsSidebarItem>) {
        self._selectedItem = selectedItem
    }
    
    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("General") {
                    sidebarRow(for: .general)
                    sidebarRow(for: .sensory)
                }
                
                Section("Widgets") {
                    sidebarRow(for: .widgets)
                    sidebarRow(for: .appearance)
                }
                
                Section("Features") {
                    sidebarRow(for: .focusTimer)
                    sidebarRow(for: .exportSharing)
                    sidebarRow(for: .shortcuts)
                    sidebarRow(for: .about)
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
            .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 240)
        } detail: {
            Form {
                switch selectedItem {
                case .general:
                    generalForm
                case .sensory:
                    sensoryForm
                case .widgets:
                    widgetsForm
                case .appearance:
                    appearanceForm
                case .focusTimer:
                    focusTimerForm
                case .exportSharing:
                    exportSharingForm
                case .shortcuts:
                    shortcutsForm
                case .about:
                    aboutForm
                }
            }
            .formStyle(.grouped)
            .padding(.top, -30)
        }
        .frame(minWidth: 840, minHeight: 600)
        .frame(width: 920, height: 680)
        .preferredColorScheme(settings.preferredColorScheme)
    }
    
    // MARK: - Sidebar Row
    @ViewBuilder
    private func sidebarRow(for item: SettingsSidebarItem) -> some View {
        if searchText.isEmpty || item.rawValue.localizedCaseInsensitiveContains(searchText) {
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
    }
    
    // MARK: - 1. General Form
    @ViewBuilder
    private var generalForm: some View {
        Section("Startup & Visibility") {
            Toggle(isOn: $settings.showInDock) {
                Text("Show in macOS Dock")
                Text("Keep the Notsky icon in the Dock and Command-Tab application switcher.")
            }
            
            Toggle(isOn: $settings.launchAtLogin) {
                Text("Launch at login")
                Text("Start Notsky desktop widgets automatically when you log in.")
            }
            
            Toggle(isOn: .constant(true)) {
                Text("Show in menu bar")
                Text("Keep the Notsky icon in the menu bar for quick access.")
            }
        }
        
        Section("Window Behavior") {
            Picker("Default window layer", selection: .constant("Desktop Canvas")) {
                Text("Desktop Canvas").tag("Desktop Canvas")
                Text("Float on Top").tag("Float on Top")
            }
            .pickerStyle(.menu)
            
            Toggle(isOn: .constant(true)) {
                Text("Follow cursor across displays")
                Text("Open spawned widgets on whichever display the pointer is currently on.")
            }
        }
    }
    
    // MARK: - 2. Sensory Form
    @ViewBuilder
    private var sensoryForm: some View {
        Section("Audio & Tactile Engine") {
            HStack {
                Toggle(isOn: $settings.soundEnabled) {
                    Text("Mechanical click sounds")
                    Text("Tactile synthesized mechanical switch clicks on completing tasks.")
                }
                Spacer()
                Button("Test") { SensoryFeedback.taskCompleted() }
                    .controlSize(.small)
            }
            
            HStack {
                Toggle(isOn: $settings.chimeEnabled) {
                    Text("Completion chime")
                    Text("Harmonic bell chime when a focus countdown timer completes.")
                }
                Spacer()
                Button("Test") { SensoryFeedback.timerFinished() }
                    .controlSize(.small)
            }
            
            HStack {
                Toggle(isOn: $settings.hapticsEnabled) {
                    Text("Trackpad haptic feedback")
                    Text("Tactile Taptic Engine pulse on checking, unchecking, or deleting tasks.")
                }
                Spacer()
                Button("Test") { SensoryFeedback.taskCompleted() }
                    .controlSize(.small)
            }
        }
    }
    
    // MARK: - 3. Widgets Form
    @ViewBuilder
    private var widgetsForm: some View {
        Section("Controls & Buttons Visibility") {
            Picker("Controls behavior", selection: $settings.autoHideControls) {
                Text("Auto-hide on Hover").tag(true)
                Text("Always Visible").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)
            
            // Side-by-Side Visual Previews
            HStack(alignment: .top, spacing: 20) {
                AutoHideCardPreview(
                    title: "Auto-hide on Hover",
                    subtitle: "Distraction-free. Buttons and options fade in when hovering.",
                    autoHide: true,
                    isSelected: settings.autoHideControls,
                    onSelect: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            settings.autoHideControls = true
                        }
                        SensoryFeedback.buttonClicked()
                    }
                )
                .frame(maxWidth: .infinity)
                
                AutoHideCardPreview(
                    title: "Always Visible",
                    subtitle: "All buttons, timers & options permanently visible.",
                    autoHide: false,
                    isSelected: !settings.autoHideControls,
                    onSelect: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            settings.autoHideControls = false
                        }
                        SensoryFeedback.buttonClicked()
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        
        Section("Grid & Placement") {
            Toggle(isOn: $settings.gridSnapping) {
                Text("Snap to desktop grid")
                Text("Automatically align card widgets to desktop grid slots with 24pt spacing.")
            }
            
            LabeledContent("Standard card dimensions") {
                Text("281 × 364 pt")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset all positions")
                    Text("Re-align all open desktop widget cards to top-left grid columns.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset to Grid") {
                    WidgetWindowManager.shared.resetWidgetPositions()
                    SensoryFeedback.buttonClicked()
                }
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - 4. Appearance & Wallpaper Packs Form
    @ViewBuilder
    private var appearanceForm: some View {
        Section("Wallpaper Pack Allocation") {
            Picker("Active Pack", selection: Binding(
                get: { packManager.activePackId },
                set: { packManager.selectPack(id: $0) }
            )) {
                ForEach(packManager.packs) { pack in
                    Text(pack.name).tag(pack.id)
                }
            }
            .pickerStyle(.menu)
            
            Text(packManager.activePack.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Pack Thumbnails Preview (Horizontally Scrollable)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pack Wallpapers (\(packManager.activePack.items.count) wallpapers auto-assigned to cards):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(packManager.activePack.items) { item in
                            VStack(alignment: .center, spacing: 4) {
                                HeaderImageView(imagePath: item.path, targetMaxPixelSize: 200)
                                    .frame(width: 80, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                                
                                Text(item.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 80)
                                    .foregroundStyle(.secondary)
                            }
                            .help(item.name)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
            .padding(.vertical, 4)
            
            HStack {
                Button("Apply Pack to All Existing Cards") {
                    packManager.applyActivePackToAllNotes(store: WidgetWindowManager.shared.store)
                }
                .controlSize(.small)
                
                Spacer()
                
                Button("Import Custom Folder as Pack...") {
                    chooseWallpaperFolder()
                }
                .controlSize(.small)
            }
        }
        
        Section("Theme & Interface") {
            Picker("Theme", selection: $settings.appearanceMode) {
                Text("System").tag("System")
                Text("Dark").tag("Dark")
                Text("Light").tag("Light")
            }
            .pickerStyle(.menu)
            
            LabeledContent("Interface size") {
                Picker("", selection: $settings.interfaceScale) {
                    Text("Small").tag("Small")
                    Text("Medium").tag("Medium")
                    Text("Large").tag("Large")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            Slider(value: $settings.backgroundOpacity, in: 0.35...1.0) {
                Text("Background density")
            } minimumValueLabel: {
                Text("Translucent").font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("Opaque").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - 5. Focus Timer Form
    @ViewBuilder
    private var focusTimerForm: some View {
        Section("Session Durations") {
            Picker("Focus session duration", selection: $pomodoro.focusDurationMinutes) {
                ForEach([15, 20, 25, 30, 45, 60], id: \.self) { mins in
                    Text("\(mins) minutes").tag(mins)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Break duration", selection: $pomodoro.breakDurationMinutes) {
                ForEach([5, 10, 15, 20], id: \.self) { mins in
                    Text("\(mins) minutes").tag(mins)
                }
            }
            .pickerStyle(.menu)
        }
        
        Section("Coordinated Timer Behavior") {
            Toggle(isOn: $settings.autoPauseTimers) {
                Text("Auto-pause adjacent timers")
                Text("Ensure only one note timer runs at a time across your desktop canvas.")
            }
        }
    }
    
    // MARK: - 6. 4K Export Form
    @ViewBuilder
    private var exportSharingForm: some View {
        Section("Export Quality & Scaling") {
            LabeledContent("Image resolution") {
                Text("4K UHD (2400 × 2400 px @ 4x)")
                    .foregroundStyle(.secondary)
            }
            
            LabeledContent("Save destination") {
                Text("~/Downloads")
                    .foregroundStyle(.secondary)
            }
            
            Toggle(isOn: .constant(true)) {
                Text("Reveal in Finder")
                Text("Highlight downloaded image files in Finder for fast drag & drop sharing.")
            }
        }
    }
    
    // MARK: - 7. Shortcuts Form
    @ViewBuilder
    private var shortcutsForm: some View {
        Section("Keyboard Shortcuts") {
            LabeledContent("Toggle Notes Shelf (Drawer)") {
                HStack(spacing: 6) {
                    shortcutBadge("Double-tap ⌃")
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    shortcutBadge("⌘ ⇧ D")
                }
            }
            LabeledContent("Dismiss Notes Shelf") {
                shortcutBadge("Esc")
            }
            LabeledContent("New Task Group Card") {
                shortcutBadge("⌘ N")
            }
            LabeledContent("New Freeform Note Card") {
                shortcutBadge("⌘ ⇧ N")
            }
            LabeledContent("Open Notsky Settings") {
                shortcutBadge("⌘ ,")
            }
            LabeledContent("Add Next Task in Row") {
                shortcutBadge("Return ↵")
            }
            LabeledContent("Quit Notsky") {
                shortcutBadge("⌘ Q")
            }
        }
        
        Section("Widget Controls") {
            LabeledContent("Pin / Wallpaper Canvas Mode") {
                shortcutBadge("Click [ 📌 ]")
            }
            LabeledContent("Download 4K Master Image") {
                shortcutBadge("Click [ ⤓ ]")
            }
        }
    }
    
    // MARK: - 8. About Form
    @ViewBuilder
    private var aboutForm: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notsky")
                        .font(.headline)
                    Text("Version 1.0.0 (Native macOS)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Minimalist glassmorphic desktop widget notes & focus studio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        
        Section("Platform") {
            LabeledContent("Architecture", value: "Apple Silicon Native")
            LabeledContent("Frameworks", value: "SwiftUI & AppKit")
        }
    }
    
    // MARK: - Helpers
    private func shortcutBadge(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
    
    private func chooseWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Wallpaper Images Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            packManager.setCustomFolder(url: url)
        }
    }
}

// MARK: - Auto-Hide vs Always-Visible Exact Card Preview
private struct AutoHideCardPreview: View {
    let title: String
    let subtitle: String
    let autoHide: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering: Bool = false
    
    private var isDark: Bool { colorScheme == .dark }
    private var showControls: Bool { !autoHide || isHovering }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Exact Live Note Card (Zero letterbox / fills column)
                ExactCardMockView(
                    showControls: showControls,
                    isDark: isDark
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3.5 : 0)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.35) : Color.black.opacity(isDark ? 0.20 : 0.08), radius: isSelected ? 12 : 8, x: 0, y: 4)
                .onHover { isHovering = $0 }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: showControls)
                
                // Selection Radio & Label aligned across column width
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .padding(.top, 1)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exact Card Mock View (Matches Live Desktop Widget 1:1)
private struct ExactCardMockView: View {
    let showControls: Bool
    let isDark: Bool
    
    private let cardWidth: CGFloat = 308
    private let cardHeight: CGFloat = 385
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { cardHeight - headerHeight }
    private let cornerRadius: CGFloat = 40
    
    private var wallpaperPath: String {
        AppSettings.shared.defaultWallpaper
    }
    
    private var sheetBackgroundColor: Color {
        isDark ? Color(white: 0.12).opacity(0.85) : Color.white.opacity(0.90)
    }
    
    private var taskTextColor: Color {
        isDark ? Color.white : Color.black
    }
    
    private var completedTaskColor: Color {
        isDark ? Color(white: 0.45) : Color(red: 0.83, green: 0.83, blue: 0.83)
    }
    
    private var buttonIconColor: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.75)
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
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. Exact Full-Card Background Image (Loads /Users/romeet/Downloads/red_distortion_2.heic)
            HeaderImageView(imagePath: wallpaperPath)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // 2. Top Title & Ambient Focus Capsule
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text("Daily Focus")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(taskTextColor)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(sheetBackgroundColor, in: Capsule())
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                        .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                    
                    if showControls {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.orange)
                            Text("25:00")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(taskTextColor.opacity(0.88))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(sheetBackgroundColor, in: Capsule())
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                        .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                    }
                }
                .frame(maxWidth: cardWidth - 28)
                Spacer(minLength: 0)
            }
            .frame(width: cardWidth, height: headerHeight)
            
            // 3. Foreground Content Sheet
            ZStack(alignment: .top) {
                // Frosted Blurred Wallpaper Underlay
                HeaderImageView(imagePath: wallpaperPath)
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
                    if showControls {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(buttonIconColor)
                                .frame(width: 40, height: 40)
                                .background(sheetBackgroundColor, in: Circle())
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.to.line").font(.system(size: 13, weight: .medium))
                                Image(systemName: "pin").font(.system(size: 13, weight: .medium))
                                Image(systemName: "photo.on.rectangle").font(.system(size: 13, weight: .medium))
                                Image(systemName: "trash").font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(buttonIconColor)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(sheetBackgroundColor, in: Capsule())
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                        }
                        .frame(width: cardWidth - 28)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    
                    if !showControls {
                        Spacer(minLength: 22)
                    }
                    
                    // Task List
                    VStack(alignment: .leading, spacing: 14) {
                        exactTaskRow(index: 1, text: "Refine widget glassmorphism", done: true)
                        exactTaskRow(index: 2, text: "Implement 2-column grid layout", done: true)
                        exactTaskRow(index: 3, text: "Tune dark mode ambient shadows", done: false)
                    }
                    .frame(width: cardWidth - 46, alignment: .leading)
                    .padding(.top, showControls ? 6 : 0)
                    .padding(.bottom, showControls ? 8 : 0)
                    
                    Spacer(minLength: showControls ? 0 : 22)
                    
                    if showControls {
                        HStack {
                            Spacer()
                            Text("Add Group")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundStyle(buttonIconColor)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(sheetBackgroundColor, in: Capsule())
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                        }
                        .frame(width: cardWidth)
                        .padding(.trailing, 16)
                        .padding(.bottom, 14)
                    }
                }
            }
            .frame(width: cardWidth, height: sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .offset(y: headerHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.20), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.12 : 0.06), radius: 16, x: 0, y: 6)
    }
    
    private func exactTaskRow(index: Int, text: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index).")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(done ? completedTaskColor.opacity(isDark ? 0.75 : 0.65) : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40)))
                .frame(minWidth: 18, alignment: .leading)
                .padding(.top, 1)
            
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .default))
                .tracking(-0.4)
                .foregroundStyle(done ? completedTaskColor : taskTextColor)
                .strikethrough(done, color: completedTaskColor.opacity(isDark ? 0.75 : 0.65))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
