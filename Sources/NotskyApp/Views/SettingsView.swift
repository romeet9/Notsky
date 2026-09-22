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
        case .general: return "gearshape"
        case .sensory: return "speaker.wave.2"
        case .widgets: return "square.grid.2x2"
        case .appearance: return "paintpalette"
        case .focusTimer: return "timer"
        case .exportSharing: return "square.and.arrow.up"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Native macOS Settings Sidebar View
public struct SettingsSidebarView: View {
    @ObservedObject private var manager = SettingsWindowManager.shared
    @State private var searchText: String = ""
    
    public init() {}
    
    public var body: some View {
        List(selection: $manager.currentItem) {
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
    }
    
    @ViewBuilder
    private func sidebarRow(for item: SettingsSidebarItem) -> some View {
        if searchText.isEmpty || item.rawValue.localizedCaseInsensitiveContains(searchText) {
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
    }
}

// MARK: - Native macOS Settings Detail View
@MainActor
public struct SettingsDetailView: View {
    @ObservedObject private var manager = SettingsWindowManager.shared
    @Bindable private var settings = AppSettings.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            switch manager.currentItem {
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
    }
    
    // MARK: - 1. General Form
    @ViewBuilder
    private var generalForm: some View {
        Section("Startup & Visibility") {
            Toggle(isOn: $settings.launchAtLogin) {
                Text("Launch at login")
                Text("Start Notsky desktop widgets automatically when you log in.")
            }
            
            Toggle(isOn: .constant(true)) {
                Text("Show in menu bar")
                Text("Keep the Notsky icon in the menu bar for quick access.")
            }
            
            Toggle(isOn: $settings.showInDock) {
                Text("Show in macOS Dock")
                Text("Keep the Notsky icon in the Dock and Command-Tab application switcher.")
            }
        }
        
        Section("Notes Shelf Drawer") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toggle Notes Shelf Drawer")
                    Text("Open the sliding bottom shelf drawer with all note cards.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Toggle Drawer") {
                    DrawerWindowManager.shared.toggleDrawer()
                    SensoryFeedback.buttonClicked()
                }
                .controlSize(.small)
            }
            
            LabeledContent("Global Keyboard Shortcut") {
                HStack(spacing: 6) {
                    shortcutBadge("⌘ ⇧ D")
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    shortcutBadge("Double-tap ⌃")
                }
            }
        }
        
        Section("Workspace & Demo Data") {
            Toggle(isOn: $settings.demoDataEnabled) {
                Text("Demo data")
                Text("Fill sample tasks, freeform notes, and AI queries into your desktop cards.")
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear Workspace")
                    Text("Remove all open cards from your desktop workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear All Cards", role: .destructive) {
                    WidgetWindowManager.shared.clearWorkspace()
                    SensoryFeedback.buttonClicked()
                }
                .controlSize(.small)
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
        Section("Control Behavior") {
            Toggle(isOn: $settings.autoHideControls) {
                Text("Auto-hide controls on hover")
                Text("Distraction-free mode. Top headers, timers, and action buttons fade in when hovering over a card.")
            }
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
                    shortcutBadge("⌘ ⇧ D")
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    shortcutBadge("Double-tap ⌃")
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

// MARK: - Combined SettingsView (backward compatibility)
public struct SettingsView: View {
    @Binding public var selectedItem: SettingsSidebarItem
    
    public init(selectedItem: Binding<SettingsSidebarItem>) {
        self._selectedItem = selectedItem
    }
    
    public var body: some View {
        NavigationSplitView {
            SettingsSidebarView()
        } detail: {
            SettingsDetailView()
        }
    }
}
