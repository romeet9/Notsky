import SwiftUI
import AppKit

public enum PomodoroPreset: String, CaseIterable {
    case focus = "Focus"
    case shortBreak = "Break"
    case longBreak = "Rest"
    
    public var title: String {
        switch self {
        case .focus: return String(localized: "25m Focus")
        case .shortBreak: return String(localized: "5m Break")
        case .longBreak: return String(localized: "15m Rest")
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .focus: return "25m"
        case .shortBreak: return "5m"
        case .longBreak: return "15m"
        }
    }
    
    var icon: RemixIcon {
        switch self {
        case .focus: return .fireFill
        case .shortBreak: return .cupFill
        case .longBreak: return .hotelBedFill
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
