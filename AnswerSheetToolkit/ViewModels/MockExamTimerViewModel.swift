import Foundation
import Combine

/// Drives the mock-exam lead-in countdown and the main timer (count-up or count-down).
///
/// Time math is driven by an injectable `now` clock so the state machine can be unit
/// tested deterministically without waiting on real time. The repeating `Timer` only
/// triggers UI ticks; all transitions go through testable methods.
@MainActor
final class MockExamTimerViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle           // not engaged
        case countingDown   // pre-start lead-in active
        case ready          // lead-in finished, waiting to begin timing
        case running        // main timer active
        case completed      // finished (final answer / stopped / time up)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var countdownRemaining: Int = 0
    /// Seconds elapsed since timing began (always counts up internally).
    @Published private(set) var elapsedSeconds: Int = 0

    private(set) var mode: MockTimerMode = .countUp
    private(set) var durationSeconds: Int = 0

    /// Injectable clock for deterministic testing.
    var now: () -> Date = { Date() }
    /// Called when the count-down reaches zero ("time's up"), with elapsed seconds.
    var onAutoComplete: ((Int) -> Void)?

    private var startDate: Date?
    private var ticker: Timer?
    private var onCountdownComplete: (() -> Void)?

    // MARK: - Computed

    var isCountingDown: Bool { phase == .countingDown }
    var isRunning: Bool { phase == .running }
    var isCompleted: Bool { phase == .completed }
    var isEngaged: Bool { phase == .countingDown || phase == .ready || phase == .running }

    /// Seconds to show on the timer: elapsed when counting up, remaining when down.
    var displaySeconds: Int {
        switch mode {
        case .countUp: return elapsedSeconds
        case .countDown: return max(0, durationSeconds - elapsedSeconds)
        }
    }

    /// The timer value formatted as `HH:MM:SS`.
    var formattedDisplay: String { Self.format(displaySeconds) }

    /// Elapsed (time taken) formatted as `HH:MM:SS`.
    var formattedElapsed: String { Self.format(elapsedSeconds) }

    static func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    // MARK: - Lifecycle

    /// Begins engagement. If `countdownSeconds > 0` the lead-in runs first; otherwise
    /// the timer becomes `.ready` immediately and `onCountdownComplete` fires.
    func engage(
        mode: MockTimerMode,
        durationSeconds: Int,
        countdownSeconds: Int,
        onCountdownComplete: @escaping () -> Void
    ) {
        stopTicker()
        self.mode = mode
        self.durationSeconds = max(0, durationSeconds)
        self.onCountdownComplete = onCountdownComplete
        elapsedSeconds = 0
        startDate = nil
        if countdownSeconds > 0 {
            countdownRemaining = countdownSeconds
            phase = .countingDown
            startTicker()
        } else {
            countdownRemaining = 0
            phase = .ready
            onCountdownComplete()
        }
    }

    /// Advances the lead-in by one second. Transitions to `.ready` and fires the
    /// completion callback at zero.
    func tickCountdown() {
        guard phase == .countingDown else { return }
        countdownRemaining -= 1
        if countdownRemaining <= 0 {
            countdownRemaining = 0
            phase = .ready
            stopTicker()
            onCountdownComplete?()
        }
    }

    /// Starts the main timer. Only valid from `.ready` (ignored once completed so a
    /// finished run never auto-restarts).
    func beginTiming() {
        guard phase == .ready else { return }
        startDate = now()
        elapsedSeconds = 0
        phase = .running
        startTicker()
    }

    /// Recomputes elapsed seconds from the start date (driven by the ticker). In
    /// count-down mode, auto-completes when the duration is reached.
    func tickElapsed() {
        guard phase == .running, let startDate else { return }
        elapsedSeconds = max(0, Int(now().timeIntervalSince(startDate).rounded()))
        if mode == .countDown, elapsedSeconds >= durationSeconds {
            elapsedSeconds = durationSeconds
            stopTicker()
            phase = .completed
            onAutoComplete?(elapsedSeconds)
        }
    }

    /// Stops timing and marks completed. Returns the recorded elapsed seconds if the
    /// timer was actually running (so a result can be saved), otherwise `nil`.
    @discardableResult
    func stop() -> Int? {
        let wasRunning = phase == .running
        if wasRunning, let startDate {
            elapsedSeconds = max(0, Int(now().timeIntervalSince(startDate).rounded()))
            if mode == .countDown {
                elapsedSeconds = min(elapsedSeconds, durationSeconds)
            }
        }
        stopTicker()
        let result = wasRunning ? elapsedSeconds : nil
        if isEngaged {
            phase = .completed
        }
        return result
    }

    /// Fully resets to idle (e.g. when switching sheets or disabling mock mode).
    func reset() {
        stopTicker()
        phase = .idle
        countdownRemaining = 0
        elapsedSeconds = 0
        startDate = nil
        onCountdownComplete = nil
    }

    // MARK: - Ticker

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                switch self.phase {
                case .countingDown: self.tickCountdown()
                case .running: self.tickElapsed()
                default: break
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
