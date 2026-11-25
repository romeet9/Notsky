import AppKit
import Carbon

/// Push-to-talk shortcut presets for the Voice Open card.
public enum VoiceHotKeyPreset: String, CaseIterable, Identifiable {
    case optionSpace
    case controlSpace
    case optionCommandSpace
    case f5

    public var id: String { rawValue }

    var keyCode: UInt32 {
        switch self {
        case .f5: return UInt32(kVK_F5)
        default: return UInt32(kVK_Space)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionSpace: return UInt32(optionKey)
        case .controlSpace: return UInt32(controlKey)
        case .optionCommandSpace: return UInt32(optionKey | cmdKey)
        case .f5: return 0
        }
    }

    /// Compact glyph form used in pills, badges and status lines.
    public var display: String {
        switch self {
        case .optionSpace: return "⌥Space"
        case .controlSpace: return "⌃Space"
        case .optionCommandSpace: return "⌥⌘Space"
        case .f5: return "F5"
        }
    }
}

// File-scope constants so the C callback below can read them without touching actor state.
private let voiceHotKeySignature: OSType = 0x4E545356 // 'NTSV'
private let voiceHotKeyIdentifier: UInt32 = 10

/// A global hold-to-talk hot key. Carbon delivers both key-down and key-up for registered
/// hot keys, which is what push-to-talk needs, and it works without Accessibility permission.
@MainActor
final class VoiceHotKey {
    static let shared = VoiceHotKey()

    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers the preset, replacing any previous registration. Returns false when macOS refused it.
    @discardableResult
    func register(_ preset: VoiceHotKeyPreset) -> Bool {
        unregister()
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: voiceHotKeySignature, id: voiceHotKeyIdentifier)
        let status = RegisterEventHotKey(preset.keyCode, preset.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
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
            guard status == noErr,
                  hotKeyID.signature == voiceHotKeySignature,
                  hotKeyID.id == voiceHotKeyIdentifier else {
                return OSStatus(eventNotHandledErr)
            }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if pressed {
                        VoiceHotKey.shared.onPress()
                    } else {
                        VoiceHotKey.shared.onRelease()
                    }
                }
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, specs.count, &specs, nil, &handlerRef)
    }
}
