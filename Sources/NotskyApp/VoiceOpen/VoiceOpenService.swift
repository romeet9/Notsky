import AppKit
import AVFoundation
import Speech

/// Push-to-talk voice commands for Notsky itself (tasks, notes, music), behind the Voice card.
/// Audio goes straight from the mic tap into the recognizer; nothing is recorded or stored,
/// and the audio engine stops the moment the key (or the orb) is released.
@MainActor
@Observable
public final class VoiceOpenService {
    public static let shared = VoiceOpenService()

    public enum Phase: Equatable {
        case idle, listening, thinking, done, failed, needsPermission
    }

    public enum PermissionIssue: Equatable { case microphone, speech }

    public private(set) var phase: Phase = .idle
    public private(set) var transcript = ""
    /// Confirmation line shown under the orb after a command succeeds.
    public private(set) var confirmation: String?
    public private(set) var canUndo = false
    /// True once a music command ran: keeps the Now Playing service alive without a Now Playing card.
    public private(set) var musicRequested = false
    public private(set) var failureMessage: String?
    public private(set) var permissionIssue: PermissionIssue?
    public private(set) var isActive = false
    public private(set) var hotKeyRegistered = false
    public private(set) var appIsActive = NSApp?.isActive ?? false
    public private(set) var micStatus: AVAuthorizationStatus = .notDetermined
    public private(set) var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    public private(set) var onDeviceAvailable = false

    public var hotKeyPreset: VoiceHotKeyPreset {
        didSet {
            guard hotKeyPreset != oldValue else { return }
            UserDefaults.standard.set(hotKeyPreset.rawValue, forKey: Self.kHotKey)
            if isActive { hotKeyRegistered = VoiceHotKey.shared.register(hotKeyPreset) }
        }
    }

    /// Smoothed mic level 0...1. Not observed: the orb reads it every animation frame.
    @ObservationIgnored public private(set) var level: Double = 0

    @ObservationIgnored private static let kHotKey = "notsky.voiceOpen.hotKey"
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var session = 0
    @ObservationIgnored private var awaitingFinal = false
    @ObservationIgnored private var undoAction: (@MainActor () -> Void)?
    @ObservationIgnored private var mouseUpMonitor: Any?
    @ObservationIgnored private var finalizeWork: DispatchWorkItem?
    @ObservationIgnored private var listenCapWork: DispatchWorkItem?
    @ObservationIgnored private var resetWork: DispatchWorkItem?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var requestingPermission = false

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.kHotKey).flatMap(VoiceHotKeyPreset.init(rawValue:))
        hotKeyPreset = stored ?? .optionSpace
    }

    // MARK: - Lifecycle

    /// Runs (hot key, app-active observers) only while at least one Voice card exists.
    public func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            VoiceHotKey.shared.onPress = { [weak self] in self?.beginListening() }
            VoiceHotKey.shared.onRelease = { [weak self] in self?.endListening() }
            hotKeyRegistered = VoiceHotKey.shared.register(hotKeyPreset)
            refreshPermissions()
            appIsActive = NSApp.isActive
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appIsActive = true }
            })
            observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appIsActive = false }
            })
        } else {
            VoiceHotKey.shared.unregister()
            hotKeyRegistered = false
            stopAudio()
            task?.cancel()
            task = nil
            removeMouseUpMonitor()
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            session += 1
            resetToIdle()
            if musicRequested {
                musicRequested = false
                WidgetWindowManager.shared.refreshNowPlayingService()
            }
        }
    }

    // MARK: - Permissions

    public func refreshPermissions() {
        if recognizer == nil {
            recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
        onDeviceAvailable = recognizer?.supportsOnDeviceRecognition ?? false
        if phase == .needsPermission, micStatus == .authorized, speechStatus == .authorized {
            resetToIdle()
        }
    }

    public func requestPermissions() {
        guard !requestingPermission else { return }
        requestingPermission = true
        Self.requestSpeechAccess { _ in
            Self.requestMicAccess { _ in
                MainActor.assumeIsolated {
                    let service = VoiceOpenService.shared
                    service.requestingPermission = false
                    service.refreshPermissions()
                    service.checkPermissionIssue()
                }
            }
        }
    }

    public func openPrivacySettings(_ issue: PermissionIssue) {
        let anchor = issue == .microphone ? "Privacy_Microphone" : "Privacy_SpeechRecognition"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    private func checkPermissionIssue() -> Bool {
        if micStatus == .denied || micStatus == .restricted {
            permissionIssue = .microphone
        } else if speechStatus == .denied || speechStatus == .restricted {
            permissionIssue = .speech
        } else {
            permissionIssue = nil
        }
        if permissionIssue != nil {
            cancelReset()
            phase = .needsPermission
            return true
        }
        return false
    }

    private nonisolated static func requestSpeechAccess(_ done: @escaping @Sendable (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in done(status == .authorized) }
    }

    /// Calls back on the main queue.
    private nonisolated static func requestMicAccess(_ done: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { done(granted) }
        }
    }

    // MARK: - Push to talk

    public func beginListening() {
        guard isActive, phase != .listening, !awaitingFinal, !requestingPermission else { return }
        refreshPermissions()
        if micStatus == .notDetermined || speechStatus == .notDetermined {
            requestPermissions()
            return
        }
        if checkPermissionIssue() { return }
        guard let recognizer, recognizer.isAvailable else {
            fail(String(localized: "Speech recognition isn't available right now"))
            return
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail(String(localized: "No microphone found"))
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        request.contextualStrings = Self.contextualStrings()

        input.removeTap(onBus: 0)
        Self.installTap(on: input, format: format, request: request)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            fail(String(localized: "Couldn't start the microphone"))
            return
        }

        session += 1
        self.engine = engine
        self.request = request
        task = Self.startRecognition(recognizer, request: request, session: session)

        cancelReset()
        confirmation = nil
        undoAction = nil
        canUndo = false
        failureMessage = nil
        transcript = ""
        level = 0
        phase = .listening
        SensoryFeedback.buttonClicked()

        // Safety cap in case a key-up is ever lost.
        let cap = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.endListening() } }
        listenCapWork = cap
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: cap)
    }

    /// Press-and-hold on the orb. Release is caught by a mouse-up monitor, so it still ends
    /// listening when the card's layout swaps the orb view out mid-hold.
    public func beginListeningFromPointer() {
        beginListening()
        guard phase == .listening, mouseUpMonitor == nil else { return }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            MainActor.assumeIsolated { VoiceOpenService.shared.endListening() }
            return event
        }
    }

    private func removeMouseUpMonitor() {
        if let mouseUpMonitor { NSEvent.removeMonitor(mouseUpMonitor) }
        mouseUpMonitor = nil
    }

    public func endListening() {
        removeMouseUpMonitor()
        guard phase == .listening else { return }
        listenCapWork?.cancel()
        listenCapWork = nil
        stopAudio()
        phase = .thinking
        awaitingFinal = true
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.finalizeTranscript() } }
        finalizeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func stopAudio() {
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        request?.endAudio()
        level = 0
    }

    private nonisolated static func installTap(on input: AVAudioInputNode, format: AVAudioFormat, request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            let rms = Self.normalizedLevel(buffer)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { VoiceOpenService.shared.ingestLevel(rms) }
            }
        }
    }

    private nonisolated static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(Double(rms), 1e-7))
        return min(max((db + 55) / 45, 0), 1)
    }

    private nonisolated static func startRecognition(_ recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest, session: Int) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    VoiceOpenService.shared.recognitionUpdate(text: text, isFinal: isFinal, failed: failed, session: session)
                }
            }
        }
    }

    private func ingestLevel(_ value: Double) {
        guard phase == .listening else { return }
        level = level * 0.65 + value * 0.35
    }

    private func recognitionUpdate(text: String?, isFinal: Bool, failed: Bool, session: Int) {
        guard session == self.session, phase == .listening || awaitingFinal else { return }
        if let text, !text.isEmpty { transcript = text }
        if awaitingFinal && (isFinal || failed) { finalizeTranscript() }
    }

    private func finalizeTranscript() {
        guard awaitingFinal else { return }
        awaitingFinal = false
        finalizeWork?.cancel()
        finalizeWork = nil
        task?.cancel()
        task = nil
        request = nil
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            fail(String(localized: "Didn't catch that. Hold and try again."))
            return
        }
        let current = session
        Task { await resolve(text, session: current) }
    }

    // MARK: - Resolve & run

    private func resolve(_ text: String, session current: Int) async {
        let command = VoiceCommand.parse(text)
        do {
            let done = try await VoiceActions.run(command)
            guard session == current, phase == .thinking else { return }
            confirmation = done.message
            undoAction = done.undo
            canUndo = done.undo != nil
            failureMessage = nil
            phase = .done
            SensoryFeedback.buttonClicked()
            scheduleReset(after: done.undo != nil ? 5 : 2.8)
        } catch let failure as VoiceActions.Failure {
            guard session == current, phase == .thinking else { return }
            fail(failure.message, after: 4.5)
        } catch {
            guard session == current, phase == .thinking else { return }
            fail(VoiceCommand.hint, after: 4.5)
        }
    }

    /// Reverses the last task, note or new-widget command while the confirmation is showing.
    public func undo() {
        guard phase == .done, let action = undoAction else { return }
        undoAction = nil
        canUndo = false
        action()
        confirmation = String(localized: "Undone")
        SensoryFeedback.buttonClicked()
        scheduleReset(after: 1.6)
    }

    /// Music commands work without a Now Playing card; this keeps the service running while a Voice card exists.
    func keepMusicRunning() {
        musicRequested = true
        NowPlayingService.shared.setActive(true)
    }

    private static func contextualStrings() -> [String] {
        let titles = WidgetWindowManager.shared.store.notes
            .filter { $0.cardType == .tasks || $0.cardType == .notes }
            .map(\.title)
        return ["add task", "new task group", "add note", "new note", "remind me to", "next song", "previous song", "what's playing"] + Array(titles.prefix(40))
    }

    private func fail(_ message: String, after seconds: TimeInterval = 3.2) {
        failureMessage = message
        phase = .failed
        scheduleReset(after: seconds)
    }

    private func scheduleReset(after seconds: TimeInterval) {
        cancelReset()
        let expected = phase
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.phase == expected else { return }
                self.resetToIdle()
            }
        }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func cancelReset() {
        resetWork?.cancel()
        resetWork = nil
    }

    private func resetToIdle() {
        cancelReset()
        listenCapWork?.cancel()
        finalizeWork?.cancel()
        awaitingFinal = false
        phase = .idle
        transcript = ""
        confirmation = nil
        undoAction = nil
        canUndo = false
        failureMessage = nil
        permissionIssue = nil
        level = 0
    }
}
