import SwiftUI
import ServiceManagement

@Observable
public final class AppSettings {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let kLaunchAtLogin = "notsky.launchAtLogin"
    private let kShowInDock = "notsky.showInDock"
    private let kSoundEnabled = "notsky.soundEnabled"
    private let kHapticsEnabled = "notsky.hapticsEnabled"
    private let kChimeEnabled = "notsky.chimeEnabled"
    private let kGridSnapping = "notsky.gridSnapping"
    private let kAppearanceMode = "notsky.appearanceMode"
    private let kInterfaceScale = "notsky.interfaceScale"
    private let kBackgroundOpacity = "notsky.backgroundOpacity"
    private let kDefaultWallpaper = "notsky.defaultWallpaper"
    private let kAutoPauseTimers = "notsky.autoPauseTimers"
    private let kAutoHideControls = "notsky.autoHideControls"
    
    public var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: kShowInDock)
            applyDockPolicy()
        }
    }
    
    public var autoHideControls: Bool {
        didSet {
            defaults.set(autoHideControls, forKey: kAutoHideControls)
        }
    }
    
    public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: kLaunchAtLogin)
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    public var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: kSoundEnabled)
            SensoryFeedback.soundEnabled = soundEnabled
            PomodoroManager.shared.isSoundEnabled = soundEnabled
        }
    }
    
    public var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: kHapticsEnabled)
            SensoryFeedback.hapticsEnabled = hapticsEnabled
            PomodoroManager.shared.isHapticsEnabled = hapticsEnabled
        }
    }
    
    public var chimeEnabled: Bool {
        didSet {
            defaults.set(chimeEnabled, forKey: kChimeEnabled)
            SensoryFeedback.chimeEnabled = chimeEnabled
            PomodoroManager.shared.isChimeEnabled = chimeEnabled
        }
    }
    
    public var gridSnapping: Bool {
        didSet {
            defaults.set(gridSnapping, forKey: kGridSnapping)
        }
    }
    
    public var appearanceMode: String {
        didSet {
            defaults.set(appearanceMode, forKey: kAppearanceMode)
            applyAppearance()
        }
    }
    
    public var interfaceScale: String {
        didSet {
            defaults.set(interfaceScale, forKey: kInterfaceScale)
        }
    }
    
    public var backgroundOpacity: Double {
        didSet {
            defaults.set(backgroundOpacity, forKey: kBackgroundOpacity)
        }
    }
    
    public var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "Dark": return .dark
        case "Light": return .light
        default: return nil
        }
    }
    
    public var scaleFactor: CGFloat {
        switch interfaceScale {
        case "Small": return 0.90
        case "Large": return 1.10
        default: return 1.0
        }
    }
    
    public func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case "Dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            case "Light":
                NSApp.appearance = NSAppearance(named: .aqua)
            default:
                NSApp.appearance = nil
            }
        }
    }
    
    public func applyDockPolicy() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(self.showInDock ? .regular : .accessory)
        }
    }
    
    public var defaultWallpaper: String {
        didSet {
            defaults.set(defaultWallpaper, forKey: kDefaultWallpaper)
        }
    }
    
    public var autoPauseTimers: Bool {
        didSet {
            defaults.set(autoPauseTimers, forKey: kAutoPauseTimers)
        }
    }
    
    private init() {
        self.launchAtLogin = defaults.bool(forKey: kLaunchAtLogin)
        self.showInDock = defaults.object(forKey: kShowInDock) == nil ? true : defaults.bool(forKey: kShowInDock)
        self.soundEnabled = defaults.object(forKey: kSoundEnabled) == nil ? true : defaults.bool(forKey: kSoundEnabled)
        self.hapticsEnabled = defaults.object(forKey: kHapticsEnabled) == nil ? true : defaults.bool(forKey: kHapticsEnabled)
        self.chimeEnabled = defaults.object(forKey: kChimeEnabled) == nil ? true : defaults.bool(forKey: kChimeEnabled)
        self.gridSnapping = defaults.object(forKey: kGridSnapping) == nil ? true : defaults.bool(forKey: kGridSnapping)
        self.appearanceMode = defaults.string(forKey: kAppearanceMode) ?? "System"
        self.interfaceScale = defaults.string(forKey: kInterfaceScale) ?? "Medium"
        self.backgroundOpacity = defaults.object(forKey: kBackgroundOpacity) == nil ? 0.85 : defaults.double(forKey: kBackgroundOpacity)
        self.defaultWallpaper = defaults.string(forKey: kDefaultWallpaper) ?? WallpaperPackManager.builtInPacks().first?.items.first?.path ?? WallpaperPackManager.defaultFallbackPath
        self.autoPauseTimers = defaults.object(forKey: kAutoPauseTimers) == nil ? true : defaults.bool(forKey: kAutoPauseTimers)
        self.autoHideControls = defaults.object(forKey: kAutoHideControls) == nil ? true : defaults.bool(forKey: kAutoHideControls)
        
        // Sync to SensoryFeedback, Dock policy & NSApp appearance
        SensoryFeedback.soundEnabled = self.soundEnabled
        SensoryFeedback.hapticsEnabled = self.hapticsEnabled
        SensoryFeedback.chimeEnabled = self.chimeEnabled
        applyAppearance()
        applyDockPolicy()
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Ignore sandbox / unbundled execution warning during debug builds
            }
        }
    }
}
