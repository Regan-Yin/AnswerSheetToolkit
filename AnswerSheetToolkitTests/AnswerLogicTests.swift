import XCTest
@testable import AnswerSheetToolkit

final class AnswerLogicTests: XCTestCase {

    // MARK: Validation / capitalization

    func testLowercaseBecomesUppercase() {
        XCTAssertEqual(AnswerValidator.normalize("a"), "A")
        XCTAssertEqual(AnswerValidator.normalize("z"), "Z")
        XCTAssertEqual(AnswerValidator.normalize("A"), "A")
    }

    func testNumbersSymbolsWhitespaceAreRejected() {
        XCTAssertNil(AnswerValidator.normalize("1"))
        XCTAssertNil(AnswerValidator.normalize("@"))
        XCTAssertNil(AnswerValidator.normalize(" "))
        XCTAssertNil(AnswerValidator.normalize(""))
        XCTAssertNil(AnswerValidator.normalize("ab"))
        XCTAssertNil(AnswerValidator.normalize("\t"))
    }

    func testIsValidLetter() {
        XCTAssertTrue(AnswerValidator.isValidLetter("c"))
        XCTAssertFalse(AnswerValidator.isValidLetter("5"))
    }

    // MARK: Answer-choice restriction

    func testOptionCountRestrictsToFirstNLetters() {
        // Default A–D (4 options).
        XCTAssertEqual(AnswerValidator.normalize("a", optionCount: 4), "A")
        XCTAssertEqual(AnswerValidator.normalize("d", optionCount: 4), "D")
        XCTAssertNil(AnswerValidator.normalize("e", optionCount: 4))
        XCTAssertNil(AnswerValidator.normalize("w", optionCount: 4))
        XCTAssertNil(AnswerValidator.normalize("z", optionCount: 4))
    }

    func testOptionCountWiderRange() {
        XCTAssertEqual(AnswerValidator.normalize("e", optionCount: 5), "E")
        XCTAssertNil(AnswerValidator.normalize("f", optionCount: 5))
        XCTAssertEqual(AnswerValidator.normalize("z", optionCount: 26), "Z")
    }

    // MARK: Auto-advance index calculation

    func testNextAdvancesByOne() {
        XCTAssertEqual(GridNavigator.next(from: 0, count: 100), 1)
        XCTAssertEqual(GridNavigator.next(from: 98, count: 100), 99) // Q99 -> Q100
    }

    func testNextClampsAtLastQuestion() {
        XCTAssertEqual(GridNavigator.next(from: 99, count: 100), 99) // stays within bounds
    }

    func testPreviousMovesBack() {
        XCTAssertEqual(GridNavigator.previous(from: 1, count: 100), 0)
    }

    func testPreviousClampsAtFirst() {
        XCTAssertEqual(GridNavigator.previous(from: 0, count: 100), 0)
    }

    func testIsLast() {
        XCTAssertTrue(GridNavigator.isLast(99, count: 100))
        XCTAssertFalse(GridNavigator.isLast(0, count: 100))
    }

    func testClamp() {
        XCTAssertEqual(GridNavigator.clamp(-5, count: 10), 0)
        XCTAssertEqual(GridNavigator.clamp(99, count: 10), 9)
        XCTAssertEqual(GridNavigator.clamp(0, count: 0), 0)
    }
}
