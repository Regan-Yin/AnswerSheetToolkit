import Foundation

/// How the mock-exam timer behaves once started.
enum MockTimerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Stopwatch: counts up, simply recording how long was spent.
    case countUp
    /// Countdown: starts at a configured duration and counts down to zero.
    case countDown

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .countUp: return "mock.mode.countUp"
        case .countDown: return "mock.mode.countDown"
        }
    }
}
