import XCTest
@testable import AnswerSheetToolkit

@MainActor
final class TimerTests: XCTestCase {

    private func makeTimer(now: @escaping () -> Date) -> MockExamTimerViewModel {
        let timer = MockExamTimerViewModel()
        timer.now = now
        return timer
    }

    func testFormat() {
        XCTAssertEqual(MockExamTimerViewModel.format(0), "00:00:00")
        XCTAssertEqual(MockExamTimerViewModel.format(65), "00:01:05")
        XCTAssertEqual(MockExamTimerViewModel.format(3661), "01:01:01")
    }

    func testEngageWithZeroCountdownGoesReadyImmediately() {
        var completed = false
        let timer = makeTimer(now: { Date() })
        timer.engage(mode: .countUp, durationSeconds: 0, countdownSeconds: 0) { completed = true }
        XCTAssertEqual(timer.phase, .ready)
        XCTAssertTrue(completed)
    }

    func testCountdownTicksToReady() {
        var completed = false
        let timer = makeTimer(now: { Date() })
        timer.engage(mode: .countUp, durationSeconds: 0, countdownSeconds: 3) { completed = true }
        XCTAssertEqual(timer.phase, .countingDown)
        XCTAssertEqual(timer.countdownRemaining, 3)
        timer.tickCountdown(); XCTAssertEqual(timer.countdownRemaining, 2)
        timer.tickCountdown(); XCTAssertEqual(timer.countdownRemaining, 1)
        timer.tickCountdown()
        XCTAssertEqual(timer.countdownRemaining, 0)
        XCTAssertEqual(timer.phase, .ready)
        XCTAssertTrue(completed)
    }

    func testTimerStartAndStopRecordsElapsed() {
        var current = Date(timeIntervalSince1970: 1000)
        let timer = makeTimer(now: { current })
        timer.engage(mode: .countUp, durationSeconds: 0, countdownSeconds: 0) {}
        timer.beginTiming()
        XCTAssertEqual(timer.phase, .running)
        current = Date(timeIntervalSince1970: 1042) // +42s
        let result = timer.stop()
        XCTAssertEqual(result, 42)
        XCTAssertEqual(timer.phase, .completed)
        XCTAssertEqual(timer.elapsedSeconds, 42)
        XCTAssertEqual(timer.displaySeconds, 42) // count-up shows elapsed
    }

    func testStoppedTimerDoesNotRestart() {
        var current = Date(timeIntervalSince1970: 0)
        let timer = makeTimer(now: { current })
        timer.engage(mode: .countUp, durationSeconds: 0, countdownSeconds: 0) {}
        timer.beginTiming()
        current = Date(timeIntervalSince1970: 10)
        _ = timer.stop()
        XCTAssertEqual(timer.phase, .completed)
        // beginTiming is only valid from .ready; should be ignored once completed.
        timer.beginTiming()
        XCTAssertEqual(timer.phase, .completed)
    }

    func testStopWhenNotRunningReturnsNil() {
        let timer = makeTimer(now: { Date() })
        XCTAssertNil(timer.stop()) // idle
        timer.engage(mode: .countUp, durationSeconds: 0, countdownSeconds: 5) {}
        // Stopping during countdown returns nil (no elapsed recorded) but completes.
        XCTAssertNil(timer.stop())
        XCTAssertEqual(timer.phase, .completed)
    }

    func testResetReturnsToIdle() {
        let timer = makeTimer(now: { Date() })
        timer.engage(mode: .countUp, durationSeconds: 0, countdownSeconds: 0) {}
        timer.beginTiming()
        timer.reset()
        XCTAssertEqual(timer.phase, .idle)
        XCTAssertEqual(timer.elapsedSeconds, 0)
    }

    // MARK: Count-down mode

    func testCountDownShowsRemainingAndAutoCompletesAtZero() {
        var current = Date(timeIntervalSince1970: 0)
        let timer = makeTimer(now: { current })
        var autoElapsed: Int?
        timer.onAutoComplete = { autoElapsed = $0 }
        timer.engage(mode: .countDown, durationSeconds: 60, countdownSeconds: 0) {}
        timer.beginTiming()
        XCTAssertEqual(timer.displaySeconds, 60) // shows full remaining at start

        current = Date(timeIntervalSince1970: 20)
        timer.tickElapsed()
        XCTAssertEqual(timer.displaySeconds, 40) // remaining
        XCTAssertEqual(timer.elapsedSeconds, 20)
        XCTAssertEqual(timer.phase, .running)

        current = Date(timeIntervalSince1970: 75) // past duration
        timer.tickElapsed()
        XCTAssertEqual(timer.phase, .completed)
        XCTAssertEqual(timer.displaySeconds, 0)
        XCTAssertEqual(timer.elapsedSeconds, 60)
        XCTAssertEqual(autoElapsed, 60)
    }

    func testCountDownStopBeforeZeroRecordsTimeTaken() {
        var current = Date(timeIntervalSince1970: 0)
        let timer = makeTimer(now: { current })
        timer.engage(mode: .countDown, durationSeconds: 600, countdownSeconds: 0) {}
        timer.beginTiming()
        current = Date(timeIntervalSince1970: 123)
        let taken = timer.stop()
        XCTAssertEqual(taken, 123) // time taken, not remaining
    }
}
