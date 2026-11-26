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
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .sensory: return "speaker.wave.2"
        case .widgets: return "square.grid.2x2"
        case .folders: return "folder.fill"
        case .appearance: return "paintpalette"
        case .ai: return "sparkles"
        case .linear: return "checklist"
        case .voice: return "waveform"
        case .focusTimer: return "timer"
        case .exportSharing: return "square.and.arrow.up"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}
