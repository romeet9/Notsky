import SwiftUI

@Observable
public final class PomodoroManager {
    public static let shared = PomodoroManager()

    public var focusDurationMinutes: Int = 25 {
        didSet {
            if !isTimerRunning {
                timeRemaining = focusDurationMinutes * 60
            }
        }
    }
    public var breakDurationMinutes: Int = 5
    public var isTimerRunning: Bool = false {
        didSet {
            if isTimerRunning {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    public var timeRemaining: Int = 25 * 60
    
    public var isSoundEnabled: Bool = true {
        didSet { SensoryFeedback.soundEnabled = isSoundEnabled }
    }
    public var isChimeEnabled: Bool = true {
        didSet { SensoryFeedback.chimeEnabled = isChimeEnabled }
    }
    public var isHapticsEnabled: Bool = true {
        didSet { SensoryFeedback.hapticsEnabled = isHapticsEnabled }
    }
    
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    private init() {}

    private func startTimer() {
        stopTimer()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    public var timeString: String {
        timeRemaining.minutesSecondsString
    }

    public func toggleTimer() {
        isTimerRunning.toggle()
        if isTimerRunning {
            SensoryFeedback.timerStarted()
        } else {
            SensoryFeedback.timerPaused()
        }
    }

    public func resetTimer() {
        isTimerRunning = false
        timeRemaining = focusDurationMinutes * 60
        SensoryFeedback.buttonClicked()
    }

    public func setFocusMinutes(_ minutes: Int) {
        focusDurationMinutes = minutes
        timeRemaining = minutes * 60
        isTimerRunning = false
        SensoryFeedback.buttonClicked()
    }

    public func setBreakMinutes(_ minutes: Int) {
        breakDurationMinutes = minutes
        timeRemaining = minutes * 60
        isTimerRunning = false
        SensoryFeedback.buttonClicked()
    }

    private func tick() {
        guard isTimerRunning else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            isTimerRunning = false
            SensoryFeedback.timerFinished()
            timeRemaining = focusDurationMinutes * 60
        }
    }
}
