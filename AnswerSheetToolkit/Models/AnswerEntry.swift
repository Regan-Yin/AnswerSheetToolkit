import Foundation

/// A single question's answer within an answer sheet.
///
/// `answer` is `nil` when the question is unanswered/skipped. Valid answers are a
/// single uppercase letter `A`...`Z`. The UI may render `nil` as an empty cell, but
/// exports must render `nil` as `N/A`.
struct AnswerEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var questionNumber: Int
    var answer: String?

    init(id: UUID = UUID(), questionNumber: Int, answer: String? = nil) {
        self.id = id
        self.questionNumber = questionNumber
        self.answer = answer
    }

    /// The value used in exports: the uppercase letter, or `N/A` if unanswered.
    var exportValue: String {
        answer ?? "N/A"
    }
}
