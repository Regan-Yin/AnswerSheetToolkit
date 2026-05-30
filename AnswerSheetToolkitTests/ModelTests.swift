import XCTest
@testable import AnswerSheetToolkit

final class ModelTests: XCTestCase {

    func testDefaultSheetHas100QuestionsAnd10PerRow() {
        let settings = AppSettings.default
        let sheet = AnswerSheet(
            title: "Test",
            totalQuestions: settings.defaultTotalQuestions,
            questionsPerRow: settings.defaultQuestionsPerRow
        )
        XCTAssertEqual(sheet.totalQuestions, 100)
        XCTAssertEqual(sheet.questionsPerRow, 10)
        XCTAssertEqual(sheet.answers.count, 100)
        XCTAssertEqual(sheet.rowCount, 10)
        XCTAssertTrue(sheet.answers.allSatisfy { $0.answer == nil })
        XCTAssertEqual(sheet.answers.first?.questionNumber, 1)
        XCTAssertEqual(sheet.answers.last?.questionNumber, 100)
    }

    func testRowCountRoundsUpForPartialFinalRow() {
        let sheet = AnswerSheet(title: "X", totalQuestions: 101, questionsPerRow: 10)
        XCTAssertEqual(sheet.rowCount, 11)
        XCTAssertEqual(sheet.answers.count, 101)
    }

    func testEmptyAnswerExportsAsNA() {
        let entry = AnswerEntry(questionNumber: 1, answer: nil)
        XCTAssertEqual(entry.exportValue, "N/A")
        let answered = AnswerEntry(questionNumber: 2, answer: "B")
        XCTAssertEqual(answered.exportValue, "B")
    }

    func testNormalizeAnswersRebuildsMismatchedCount() {
        var sheet = AnswerSheet(title: "X", totalQuestions: 5, questionsPerRow: 5)
        sheet.answers = [AnswerEntry(questionNumber: 1, answer: "A")] // corrupted shape
        sheet.normalizeAnswers()
        XCTAssertEqual(sheet.answers.count, 5)
        XCTAssertEqual(sheet.answers[0].answer, "A")
        XCTAssertEqual(sheet.answers[4].questionNumber, 5)
    }

    func testSettingsValidationClampsBounds() {
        var s = AppSettings.default
        s.defaultTotalQuestions = 5000
        s.defaultQuestionsPerRow = 0
        s.mockExamCountdownSeconds = 7
        let v = s.validated()
        XCTAssertEqual(v.defaultTotalQuestions, 300)
        XCTAssertEqual(v.defaultQuestionsPerRow, 1)
        XCTAssertEqual(v.mockExamCountdownSeconds, 0)
    }

    func testDefaultRowsValidationClamps() {
        var s = AppSettings.default
        s.defaultRows = 9999
        let v = s.validated()
        XCTAssertEqual(v.defaultRows, AppSettings.rowsRange.upperBound)
    }
}
