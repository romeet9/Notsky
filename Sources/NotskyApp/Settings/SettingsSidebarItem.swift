import SwiftUI
import AppKit

public enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    // General
    case general = "General"
    case sensory = "Sensory Feedback"
    
    // Widgets & Organization
    case widgets = "Desktop Widgets"
    case folders = "Folders & Organization"
    case appearance = "Appearance & Packs"
    
    // Features
    case ai = "AI"
    case linear = "Linear"
    case voice = "Voice"
    case focusTimer = "Focus Timer"
    case exportSharing = "4K Export & Share"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    public var id: String { rawValue }
    
    /// Localized display title (rawValue stays the stable identifier).
    public var localizedTitle: String {
        switch self {
        case .general: return String(localized: "General")
        case .sensory: return String(localized: "Sensory Feedback")
        case .widgets: return String(localized: "Desktop Widgets")
        case .folders: return String(localized: "Folders & Organization")
        case .appearance: return String(localized: "Appearance & Packs")
        case .ai: return String(localized: "AI")
        case .linear: return String(localized: "Linear")
        case .voice: return String(localized: "Voice")
        case .focusTimer: return String(localized: "Focus Timer")
        case .exportSharing: return String(localized: "4K Export & Share")
        case .shortcuts: return String(localized: "Shortcuts")
        case .about: return String(localized: "About")
        }
    }
    
    var icon: RemixIcon {
        switch self {
        case .general: return .settings3Line
        case .sensory: return .volumeUpLine
        case .widgets: return .layoutGridLine
        case .folders: return .folderFill
        case .appearance: return .paletteLine
        case .ai: return .sparklingLine
        case .linear: return .listCheck
        case .voice: return .voiceprintLine
        case .focusTimer: return .timerLine
        case .exportSharing: return .shareBoxLine
        case .shortcuts: return .commandLine
        case .about: return .informationLine
        }
    }
}
