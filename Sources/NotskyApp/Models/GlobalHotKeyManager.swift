import AppKit
import Carbon

public final class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    
    // Double Control Tap Tracker
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var lastControlPressTime: TimeInterval = 0
    private var isControlDown: Bool = false
    
    private init() {}
    
    public func setup() {
        registerCarbonHotKeys()
        startDoubleControlMonitor()
    }
    
    // MARK: - Carbon Global HotKeys (Works everywhere without accessibility permissions)
    
    private func registerCarbonHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                DispatchQueue.main.async {
                    if hotKeyID.id == 1 { // Cmd + Shift + D
                        DrawerWindowManager.shared.toggleDrawer()
                    } else if hotKeyID.id == 2 { // Cmd + Shift + N
                        WidgetWindowManager.shared.spawnNewFreeformNoteWidget()
                    }
                }
            }
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        // 1. Register Cmd + Shift + D (Key code 2 = 'D')
        // cmdKey = 0x0100, shiftKey = 0x0200 in Carbon
        var ref1: EventHotKeyRef?
        let hotKeyID1 = EventHotKeyID(signature: OSType(0x4E545331), id: 1) // 'NTS1'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey | shiftKey),
            hotKeyID1,
            GetApplicationEventTarget(),
            0,
            &ref1
        )
        if let ref = ref1 { hotKeyRefs.append(ref) }
        
        // 2. Register Cmd + Shift + N (Key code 45 = 'N')
        var ref2: EventHotKeyRef?
        let hotKeyID2 = EventHotKeyID(signature: OSType(0x4E545332), id: 2) // 'NTS2'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            UInt32(cmdKey | shiftKey),
            hotKeyID2,
            GetApplicationEventTarget(),
            0,
            &ref2
        )
        if let ref = ref2 { hotKeyRefs.append(ref) }
    }
    
    // MARK: - Double Control Tap Monitor
    
    private func startDoubleControlMonitor() {
        // Global monitor
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagEvent(event)
        }
        
        // Local monitor
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagEvent(event)
            return event
        }
    }
    
    private func handleFlagEvent(_ event: NSEvent) {
        let isCtrl = event.modifierFlags.contains(.control)
        
        if isCtrl && !isControlDown {
            isControlDown = true
            let now = ProcessInfo.processInfo.systemUptime
            let delta = now - lastControlPressTime
            
            if delta > 0.05 && delta < 0.45 {
                lastControlPressTime = 0
                DispatchQueue.main.async {
                    SensoryFeedback.buttonClicked()
                    DrawerWindowManager.shared.toggleDrawer()
                }
            } else {
                lastControlPressTime = now
            }
        } else if !isCtrl {
            isControlDown = false
        }
    }
}
