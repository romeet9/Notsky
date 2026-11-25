import SwiftUI
import AppKit

/// Settings pane: Appearance. Extracted from SettingsDetailView.
struct AppearanceSettingsForm: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var pomodoro = PomodoroManager.shared
    private var packManager = WallpaperPackManager.shared

    var body: some View {
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
                
                ScrollView(.horizontal) {
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
                                    .scaledFont(size: 10, weight: .medium)
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
                .scrollIndicators(.hidden)
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
            
            LabeledContent("Text size") {
                HStack(spacing: 8) {
                    Text("A").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $settings.textScale, in: AppSettings.textScaleRange, step: 0.05)
                        .frame(width: 160)
                        .accessibilityLabel("Text size")
                        .accessibilityValue(Text(settings.textScale, format: .percent.precision(.fractionLength(0))))
                    Text("A").font(.title3).foregroundStyle(.secondary)
                    Text(settings.textScale, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
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

    private func chooseWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Select Wallpaper Images Folder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            packManager.setCustomFolder(url: url)
        }
    }
}
