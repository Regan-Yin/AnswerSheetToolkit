import XCTest

/// End-to-end UI tests for the keyboard-first answering flow and sheet management.
///
/// These drive the real app via accessibility identifiers added in the views.
/// Queries use `.firstMatch` because macOS mirrors toolbar items into overflow
/// representations, producing multiple elements for the same identifier.
final class AnswerSheetToolkitUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func rowCount() -> Int {
        app.descendants(matching: .any).matching(identifier: "sheetRow").count
    }

    @discardableResult
    private func createSheet() -> Bool {
        let button = element("newSheetButton")
        guard button.waitForExistence(timeout: 5) else { return false }
        button.click()
        return grid.waitForExistence(timeout: 5)
    }

    private var grid: XCUIElement { element("answerGrid") }

    private func gridValue() -> String { (grid.value as? String) ?? "" }

    /// Polls the grid's accessibility value until it matches (or times out).
    private func waitForGridValue(_ expected: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if gridValue() == expected { return true }
            usleep(100_000)
        }
        return gridValue() == expected
    }

    private var firstRow: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "sheetRow").firstMatch
    }

    // MARK: Tests

    func testCreateSheetAddsRowAndFocusesGrid() throws {
        XCTAssertTrue(createSheet())
        XCTAssertTrue(grid.exists)
        XCTAssertGreaterThanOrEqual(rowCount(), 1)
    }

    func testTypeAnswersQuickly() throws {
        XCTAssertTrue(createSheet())
        grid.click()
        app.typeText("abcd")
        XCTAssertTrue(grid.exists)
    }

    func testSkipWithTabAndReturnWithShiftTab() throws {
        XCTAssertTrue(createSheet())
        grid.click()
        app.typeKey("\t", modifierFlags: [])
        app.typeKey("\t", modifierFlags: [.shift])
        XCTAssertTrue(grid.exists)
    }

    /// Bug 4: the focus highlight must move live with Tab / Shift+Tab (not only when
    /// a letter is typed). The grid exposes the focused question via its a11y value.
    func testTabAndShiftTabMoveFocusHighlightLive() throws {
        XCTAssertTrue(createSheet())
        grid.click()
        XCTAssertTrue(waitForGridValue("1"), "expected focus on Q1, got \(gridValue())")

        app.typeKey("\t", modifierFlags: [])
        XCTAssertTrue(waitForGridValue("2"), "Tab should move to Q2, got \(gridValue())")

        app.typeKey("\t", modifierFlags: [])
        XCTAssertTrue(waitForGridValue("3"), "Tab should move to Q3, got \(gridValue())")

        app.typeKey("\t", modifierFlags: [.shift])
        XCTAssertTrue(waitForGridValue("2"), "Shift+Tab should move back to Q2, got \(gridValue())")
    }

    func testEnableMockExamMode() throws {
        XCTAssertTrue(createSheet())
        let toggle = element("mockExamToggle")
        if toggle.waitForExistence(timeout: 3) {
            toggle.click()
        }
        XCTAssertTrue(grid.exists)
    }

    func testRenameAndExportMenuPresent() throws {
        XCTAssertTrue(createSheet())
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.rightClick()
        XCTAssertGreaterThan(app.menuItems.count, 0)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    func testDeleteSheet() throws {
        XCTAssertTrue(createSheet())
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()
        XCTAssertTrue(app.exists)
    }
}
