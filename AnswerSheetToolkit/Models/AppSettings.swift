import Foundation

/// User-configurable application settings.
///
/// Layout fields (`defaultTotalQuestions`, `defaultQuestionsPerRow`,
/// `defaultAnswerOptionCount`) are only used as the snapshot source for *newly
/// created* sheets. They never reshape existing sheets.
struct AppSettings: Codable, Equatable, Sendable {
    var defaultTotalQuestions: Int
    var defaultQuestionsPerRow: Int
    /// Default number of rows. Editing rows or per-row recomputes total
    /// (`rows * perRow`); editing total leaves rows and per-row untouched.
    var defaultRows: Int
    /// Number of allowed answer choices, counted from `A`. 4 means A–D.
    var defaultAnswerOptionCount: Int
    /// Stored as a security-scoped bookmark-friendly path string when available.
    var exportFolderURL: URL?
    var language: LanguageMode
    var theme: ThemeMode
    /// Lead-in delay (seconds) before the timer begins, shown as "Starting in N…".
    var mockExamCountdownSeconds: Int
    /// Whether the mock-exam timer counts up (stopwatch) or down from a duration.
    var mockExamTimerMode: MockTimerMode
    /// Duration (seconds) used when `mockExamTimerMode == .countDown`.
    var mockExamDurationSeconds: Int

    // MARK: Validation bounds

    static let totalQuestionsRange = 1...300
    static let questionsPerRowRange = 1...25
    static let rowsRange = 1...300
    static let answerOptionRange = 2...26
    /// Allowed lead-in countdown durations, in seconds.
    static let countdownOptions = [0, 3, 5, 10, 30, 60]
    static let durationHoursRange = 0...23
    static let durationMinutesRange = 0...59

    static let `default` = AppSettings(
        defaultTotalQuestions: 100,
        defaultQuestionsPerRow: 10,
        defaultRows: 10,
        defaultAnswerOptionCount: 4,
        exportFolderURL: nil,
        language: .english,
        theme: .system,
        mockExamCountdownSeconds: 0,
        mockExamTimerMode: .countUp,
        mockExamDurationSeconds: 3600
    )

    init(
        defaultTotalQuestions: Int,
        defaultQuestionsPerRow: Int,
        defaultRows: Int,
        defaultAnswerOptionCount: Int,
        exportFolderURL: URL?,
        language: LanguageMode,
        theme: ThemeMode,
        mockExamCountdownSeconds: Int,
        mockExamTimerMode: MockTimerMode,
        mockExamDurationSeconds: Int
    ) {
        self.defaultTotalQuestions = defaultTotalQuestions
        self.defaultQuestionsPerRow = defaultQuestionsPerRow
        self.defaultRows = defaultRows
        self.defaultAnswerOptionCount = defaultAnswerOptionCount
        self.exportFolderURL = exportFolderURL
        self.language = language
        self.theme = theme
        self.mockExamCountdownSeconds = mockExamCountdownSeconds
        self.mockExamTimerMode = mockExamTimerMode
        self.mockExamDurationSeconds = mockExamDurationSeconds
    }

    /// Lenient decoding: missing keys fall back to defaults so older `settings.json`
    /// files (saved before new fields existed) load without being discarded.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let def = AppSettings.default
        defaultTotalQuestions = try c.decodeIfPresent(Int.self, forKey: .defaultTotalQuestions) ?? def.defaultTotalQuestions
        defaultQuestionsPerRow = try c.decodeIfPresent(Int.self, forKey: .defaultQuestionsPerRow) ?? def.defaultQuestionsPerRow
        defaultRows = try c.decodeIfPresent(Int.self, forKey: .defaultRows) ?? def.defaultRows
        defaultAnswerOptionCount = try c.decodeIfPresent(Int.self, forKey: .defaultAnswerOptionCount) ?? def.defaultAnswerOptionCount
        exportFolderURL = try c.decodeIfPresent(URL.self, forKey: .exportFolderURL)
        language = try c.decodeIfPresent(LanguageMode.self, forKey: .language) ?? def.language
        theme = try c.decodeIfPresent(ThemeMode.self, forKey: .theme) ?? def.theme
        mockExamCountdownSeconds = try c.decodeIfPresent(Int.self, forKey: .mockExamCountdownSeconds) ?? def.mockExamCountdownSeconds
        mockExamTimerMode = try c.decodeIfPresent(MockTimerMode.self, forKey: .mockExamTimerMode) ?? def.mockExamTimerMode
        mockExamDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .mockExamDurationSeconds) ?? def.mockExamDurationSeconds
    }

    /// Returns a copy with all values clamped to valid bounds.
    func validated() -> AppSettings {
        var copy = self
        copy.defaultTotalQuestions = Self.clamp(defaultTotalQuestions, to: Self.totalQuestionsRange)
        copy.defaultQuestionsPerRow = Self.clamp(defaultQuestionsPerRow, to: Self.questionsPerRowRange)
        copy.defaultRows = Self.clamp(defaultRows, to: Self.rowsRange)
        copy.defaultAnswerOptionCount = Self.clamp(defaultAnswerOptionCount, to: Self.answerOptionRange)
        if !Self.countdownOptions.contains(copy.mockExamCountdownSeconds) {
            copy.mockExamCountdownSeconds = 0
        }
        copy.mockExamDurationSeconds = max(60, min(mockExamDurationSeconds, 23 * 3600 + 59 * 60))
        return copy
    }

    /// The last allowed answer letter for the default option count, e.g. "D".
    var answerChoicesPreview: String {
        let count = Self.clamp(defaultAnswerOptionCount, to: Self.answerOptionRange)
        let last = Character(UnicodeScalar(UInt8(65 + count - 1)))
        return "A–\(last)"
    }

    var durationHours: Int { mockExamDurationSeconds / 3600 }
    var durationMinutes: Int { (mockExamDurationSeconds % 3600) / 60 }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
