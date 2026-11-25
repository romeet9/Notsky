import SwiftUI
import AppKit

// MARK: - Native macOS Settings Sidebar View
public struct SettingsSidebarView: View {
    @Bindable private var manager = SettingsWindowManager.shared
    @State private var searchText: String = ""
    
    public init() {}
    
    public var body: some View {
        List(selection: $manager.currentItem) {
            Section("General") {
                sidebarRow(for: .general)
                sidebarRow(for: .sensory)
            }
            
            Section("Widgets & Organization") {
                sidebarRow(for: .widgets)
                sidebarRow(for: .folders)
                sidebarRow(for: .appearance)
            }
            
            Section("Features") {
                sidebarRow(for: .linear)
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
        if searchText.isEmpty || item.localizedTitle.localizedStandardContains(searchText) {
            Label(item.localizedTitle, systemImage: item.icon)
                .tag(item)
        }
    }
}
