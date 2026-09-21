import SwiftUI
import Combine

public final class PomodoroManager: ObservableObject {
    public static let shared = PomodoroManager()

    @Published public var focusDurationMinutes: Int = 25 {
        didSet {
            if !isTimerRunning {
                timeRemaining = focusDurationMinutes * 60
            }
        }
    }
    @Published public var breakDurationMinutes: Int = 5
    @Published public var isTimerRunning: Bool = false {
        didSet {
            if isTimerRunning {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    @Published public var timeRemaining: Int = 25 * 60
    
    @Published public var isSoundEnabled: Bool = true {
        didSet { SensoryFeedback.soundEnabled = isSoundEnabled }
    }
    @Published public var isChimeEnabled: Bool = true {
        didSet { SensoryFeedback.chimeEnabled = isChimeEnabled }
    }
    @Published public var isHapticsEnabled: Bool = true {
        didSet { SensoryFeedback.hapticsEnabled = isHapticsEnabled }
    }
    
    private var timerCancellable: AnyCancellable?

    private init() {}

    private func startTimer() {
        stopTimer()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    public var timeString: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
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
