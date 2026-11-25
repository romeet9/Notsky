import SwiftUI
import AppKit

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
