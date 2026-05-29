import XCTest
@testable import AnswerSheetToolkit

final class ExportTests: XCTestCase {

    private func makeSheet(total: Int, perRow: Int, answers: [Int: String] = [:]) -> AnswerSheet {
        var sheet = AnswerSheet(title: "S", totalQuestions: total, questionsPerRow: perRow)
        for (q, a) in answers {
            sheet.answers[q - 1].answer = a
        }
        return sheet
    }

    func testTableShape100x10Is10RowsAnd20Columns() {
        let sheet = makeSheet(total: 100, perRow: 10)
        let rows = ExportService.tableRows(for: sheet)
        XCTAssertEqual(rows.count, 10)
        XCTAssertTrue(rows.allSatisfy { $0.count == 20 })
    }

    func testTableShape120x12Is10RowsAnd24Columns() {
        let sheet = makeSheet(total: 120, perRow: 12)
        let rows = ExportService.tableRows(for: sheet)
        XCTAssertEqual(rows.count, 10)
        XCTAssertTrue(rows.allSatisfy { $0.count == 24 })
    }

    func testPartialFinalRow() {
        let sheet = makeSheet(total: 101, perRow: 10)
        let rows = ExportService.tableRows(for: sheet)
        XCTAssertEqual(rows.count, 11)
        XCTAssertEqual(rows.last?.count, 2) // one question -> 2 columns
        XCTAssertEqual(rows.last?[0], "101")
    }

    func testUnansweredExportsAsNA() {
        let sheet = makeSheet(total: 10, perRow: 10, answers: [1: "A", 3: "C"])
        let rows = ExportService.tableRows(for: sheet)
        XCTAssertEqual(rows[0][1], "A")   // Q1 answer
        XCTAssertEqual(rows[0][3], "N/A") // Q2 unanswered
        XCTAssertEqual(rows[0][5], "C")   // Q3 answer
    }

    func testTSVShapeAndContent() {
        let sheet = makeSheet(total: 10, perRow: 10, answers: [1: "A", 2: "C", 3: "B", 5: "D"])
        let tsv = ExportService.tsv(for: sheet)
        let firstLine = tsv.components(separatedBy: "\n").first ?? ""
        let cols = firstLine.components(separatedBy: "\t")
        XCTAssertEqual(cols.count, 20)
        XCTAssertEqual(cols[0], "1")
        XCTAssertEqual(cols[1], "A")
        XCTAssertEqual(cols[7], "N/A") // Q4 answer
    }

    // MARK: Worksheet / file name sanitization

    func testWorksheetNameRemovesInvalidCharacters() {
        let name = ExportService.sanitizedWorksheetName("Exam [2024]: A/B?*\\")
        XCTAssertFalse(name.contains("["))
        XCTAssertFalse(name.contains("]"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("?"))
        XCTAssertFalse(name.contains("*"))
        XCTAssertFalse(name.contains("\\"))
    }

    func testWorksheetNameTruncatedTo31() {
        let long = String(repeating: "A", count: 50)
        XCTAssertEqual(ExportService.sanitizedWorksheetName(long).count, 31)
    }

    func testWorksheetNameFallbackWhenEmpty() {
        XCTAssertEqual(ExportService.sanitizedWorksheetName("[]:*?/\\"), "Sheet")
        XCTAssertEqual(ExportService.sanitizedWorksheetName("   "), "Sheet")
    }

    func testWorksheetNamesMadeUnique() {
        let names = ExportService.uniqueWorksheetNames(for: ["Exam", "Exam", "Exam"])
        XCTAssertEqual(Set(names.map { $0.lowercased() }).count, 3)
        XCTAssertEqual(names[0], "Exam")
    }

    func testFileNameSanitization() {
        let name = ExportService.sanitizedFileName("My/Sheet:Name*?")
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("*"))
        XCTAssertFalse(name.contains("?"))
    }

    func testColumnLetters() {
        XCTAssertEqual(XLSXWriter.columnLetter(0), "A")
        XCTAssertEqual(XLSXWriter.columnLetter(25), "Z")
        XCTAssertEqual(XLSXWriter.columnLetter(26), "AA")
        XCTAssertEqual(XLSXWriter.columnLetter(27), "AB")
    }

    func testXLSXBuildsNonEmptyValidZip() {
        let sheet = makeSheet(total: 20, perRow: 10, answers: [1: "A"])
        let data = XLSXWriter.build(sheets: [sheet])
        XCTAssertGreaterThan(data.count, 100)
        // ZIP local file header magic "PK\u{03}\u{04}".
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
    }

    func testCRC32KnownValue() {
        // CRC32 of "123456789" is 0xCBF43926.
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF43926)
    }
}
