import Foundation

/// Represents one paper answer sheet.
///
/// `totalQuestions` and `questionsPerRow` are a *snapshot* captured at creation time.
/// Later changes to ``AppSettings`` must never reshape an existing sheet.
struct AnswerSheet: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// Locked at creation. Never mutated by settings changes.
    var totalQuestions: Int
    /// Locked at creation. Never mutated by settings changes.
    var questionsPerRow: Int
    /// Allowed answer choices counted from `A` (4 = A–D). Locked at creation.
    /// Optional for backward compatibility with sheets saved before this existed;
    /// `nil` means unrestricted (legacy behavior).
    var answerOptionCount: Int?

    var answers: [AnswerEntry]

    var mockExamEnabledAtCreation: Bool
    var mockExamElapsedSeconds: Int?
    var mockExamStartedAt: Date?
    var mockExamCompletedAt: Date?
    /// Timing mode and duration used for the recorded mock attempt.
    var mockExamTimerMode: MockTimerMode?
    var mockExamDurationSeconds: Int?

    var languageSnapshot: LanguageMode?
    var themeSnapshot: ThemeMode?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        totalQuestions: Int,
        questionsPerRow: Int,
        answerOptionCount: Int? = nil,
        answers: [AnswerEntry]? = nil,
        mockExamEnabledAtCreation: Bool = false,
        mockExamElapsedSeconds: Int? = nil,
        mockExamStartedAt: Date? = nil,
        mockExamCompletedAt: Date? = nil,
        mockExamTimerMode: MockTimerMode? = nil,
        mockExamDurationSeconds: Int? = nil,
        languageSnapshot: LanguageMode? = nil,
        themeSnapshot: ThemeMode? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalQuestions = max(1, totalQuestions)
        self.questionsPerRow = max(1, questionsPerRow)
        self.answerOptionCount = answerOptionCount
        self.answers = answers ?? AnswerSheet.makeEmptyAnswers(count: self.totalQuestions)
        self.mockExamEnabledAtCreation = mockExamEnabledAtCreation
        self.mockExamElapsedSeconds = mockExamElapsedSeconds
        self.mockExamStartedAt = mockExamStartedAt
        self.mockExamCompletedAt = mockExamCompletedAt
        self.mockExamTimerMode = mockExamTimerMode
        self.mockExamDurationSeconds = mockExamDurationSeconds
        self.languageSnapshot = languageSnapshot
        self.themeSnapshot = themeSnapshot
    }

    /// Number of allowed answer choices (defaults to 26 / unrestricted for legacy
    /// sheets that have no snapshot).
    var allowedAnswerCount: Int {
        if let answerOptionCount { return min(max(answerOptionCount, 1), 26) }
        return 26
    }

    /// Number of rows needed to display the sheet (final row may be partial).
    var rowCount: Int {
        Int((Double(totalQuestions) / Double(questionsPerRow)).rounded(.up))
    }

    /// Builds an array of empty answer entries with 1-based question numbers.
    static func makeEmptyAnswers(count: Int) -> [AnswerEntry] {
        (1...max(1, count)).map { AnswerEntry(questionNumber: $0, answer: nil) }
    }

    /// Ensures the answers array always has exactly `totalQuestions` entries with
    /// correct 1-based question numbers. Defensive against corrupted persisted data.
    mutating func normalizeAnswers() {
        if answers.count != totalQuestions {
            var rebuilt = AnswerSheet.makeEmptyAnswers(count: totalQuestions)
            for i in 0..<min(rebuilt.count, answers.count) {
                rebuilt[i].answer = answers[i].answer
            }
            answers = rebuilt
        }
        for i in answers.indices {
            answers[i].questionNumber = i + 1
        }
    }
}
